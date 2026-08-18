# frozen_string_literal: true

module Billing
  # Keeps the Stripe subscription quantity equal to the team's member count.
  #
  # Per-seat billing means every invite and every removal changes the bill. This
  # service is the only thing that writes the quantity, and it is written as a
  # reconciliation rather than a delta: it reads the current count, compares,
  # and does nothing if they already match. Running it twice changes nothing.
  class SyncSeats < ApplicationService
    def initialize(team:)
      @team = team
      @subscription = team.subscription
    end

    def call
      return success(:no_subscription) if @subscription.nil?
      return success(:not_billable) unless billable_status?
      return success(:missing_item) if @subscription.stripe_subscription_item_id.blank?

      seats = @team.memberships.count
      return success(:unchanged) if seats == @subscription.quantity

      update_stripe(seats)
      @subscription.update!(quantity: seats)

      success(seats)
    rescue Stripe::InvalidRequestError => e
      # The subscription is gone on Stripe's side. Local state will be corrected
      # by the deletion webhook; there is nothing to retry.
      Sentry.capture_exception(e, extra: { team_id: @team.id })
      failure(e.message)
    rescue Stripe::StripeError => e
      Sentry.capture_exception(e, extra: { team_id: @team.id })
      raise # let the job's retry policy handle transient Stripe failures
    end

    private

    # Canceled and incomplete subscriptions have no seats worth syncing.
    def billable_status? = @subscription.active?

    def update_stripe(seats)
      Stripe::SubscriptionItem.update(
        @subscription.stripe_subscription_item_id,
        { quantity: seats, proration_behavior: "create_prorations" },
        { idempotency_key: idempotency_key(seats) }
      )
    end

    # Includes the target quantity so a legitimate later change to a different
    # number is not swallowed as a duplicate of this one.
    def idempotency_key(seats)
      "seats-#{@subscription.stripe_subscription_id}-#{seats}-#{@subscription.updated_at.to_i}"
    end
  end
end
