# frozen_string_literal: true

module Billing
  # The only writer of local subscription state.
  #
  # Everything the application believes about a team's subscription comes from
  # here, driven by webhooks. Nothing in the request path asks Stripe directly,
  # and a browser redirect after checkout is never treated as proof of anything.
  #
  # Every handler is written to be re-runnable: they set absolute state from the
  # event payload rather than incrementing or toggling.
  class ProcessStripeEvent < ApplicationService
    HANDLED_TYPES = %w[
      checkout.session.completed
      customer.subscription.created
      customer.subscription.updated
      customer.subscription.deleted
      invoice.payment_succeeded
      invoice.payment_failed
    ].freeze

    def initialize(stripe_event:)
      @record = stripe_event
      @event = stripe_event.to_stripe_event
    end

    def call
      return success(:already_processed) if @record.processed?
      return ignore unless HANDLED_TYPES.include?(@event.type)

      handle
      @record.mark_processed!

      success(@event.type)
    rescue StandardError => e
      @record.mark_failed!(e)
      Sentry.capture_exception(e, extra: { stripe_event_id: @record.stripe_event_id })
      raise
    end

    private

    def object = @event.data.object

    # Unhandled event types are still marked processed. They arrived, they were
    # recorded, and there is nothing further to do — leaving them unprocessed
    # would make the failed-event view useless.
    def ignore
      @record.mark_processed!
      success(:ignored)
    end

    def handle
      case @event.type
      when "checkout.session.completed"          then handle_checkout_completed
      when "customer.subscription.created",
           "customer.subscription.updated"        then upsert_subscription
      when "customer.subscription.deleted"        then handle_subscription_deleted
      when "invoice.payment_succeeded"            then handle_payment_succeeded
      when "invoice.payment_failed"               then handle_payment_failed
      end
    end

    # Checkout tells us a subscription now exists. The subscription object
    # itself is fetched so local state is built from Stripe's own record rather
    # than from the thinner session payload.
    def handle_checkout_completed
      return if object.mode != "subscription" || object.subscription.blank?

      team = find_team(customer_id: object.customer, metadata: object.metadata)
      return if team.nil?

      subscription = Stripe::Subscription.retrieve(
        id: object.subscription, expand: [ "items.data.price" ]
      )
      write_subscription(team, subscription)
    end

    def upsert_subscription
      team = find_team(customer_id: object.customer, metadata: object.metadata)
      return if team.nil?

      write_subscription(team, object)
    end

    def handle_subscription_deleted
      subscription = Subscription.find_by(stripe_subscription_id: object.id)
      return if subscription.nil?

      subscription.update!(
        status: "canceled",
        canceled_at: Time.current,
        cancel_at_period_end: false
      )

      BillingMailer.subscription_canceled(subscription.team).deliver_later
    end

    def handle_payment_succeeded
      subscription = subscription_for_invoice
      return if subscription.nil?
      return unless subscription.status == "past_due"

      subscription.update!(status: "active")
    end

    def handle_payment_failed
      subscription = subscription_for_invoice
      return if subscription.nil?

      subscription.update!(status: "past_due")
      BillingMailer.payment_failed(subscription.team).deliver_later
    end

    def subscription_for_invoice
      id = object.respond_to?(:subscription) ? object.subscription : nil
      return nil if id.blank?

      Subscription.find_by(stripe_subscription_id: id)
    end

    # Writes the local mirror from a Stripe subscription object.
    def write_subscription(team, stripe_subscription)
      item = stripe_subscription.items.data.first

      record = Subscription.find_or_initialize_by(team: team)
      record.assign_attributes(
        stripe_subscription_id: stripe_subscription.id,
        stripe_subscription_item_id: item&.id,
        stripe_price_id: item&.price&.id,
        plan_key: plan_key_for(item&.price&.id),
        status: stripe_subscription.status,
        quantity: item&.quantity || stripe_subscription.quantity || 1,
        cancel_at_period_end: stripe_subscription.cancel_at_period_end || false,
        canceled_at: timestamp(stripe_subscription.canceled_at),
        current_period_end: timestamp(item&.current_period_end),
        trial_ends_at: timestamp(stripe_subscription.trial_end)
      )
      record.save!
      record
    end

    # Teams are found by their Stripe customer id. The metadata written at
    # checkout is a fallback for the window before the customer id is stored.
    def find_team(customer_id:, metadata: nil)
      team = Team.find_by(stripe_customer_id: customer_id) if customer_id.present?
      return team if team

      team_id = metadata.respond_to?(:[]) ? metadata["team_id"] : nil
      team = Team.find_by(id: team_id) if team_id.present?
      team&.update!(stripe_customer_id: customer_id) if team && customer_id.present?

      team
    end

    def plan_key_for(price_id)
      return nil if price_id.blank?

      Plan.all.find { |plan| plan.stripe_price_id == price_id }&.key
    end

    def timestamp(value) = value.present? ? Time.zone.at(value) : nil
  end
end
