# frozen_string_literal: true

module Billing
  # Starts a Stripe Checkout session for a per-seat subscription.
  #
  # The quantity is the team's current member count. Nothing about the returned
  # URL is trusted afterwards — the subscription only becomes real in this
  # application when the webhook arrives.
  class CreateCheckoutSession < ApplicationService
    def initialize(team:, plan:, success_url:, cancel_url:)
      @team = team
      @plan = plan
      @success_url = success_url
      @cancel_url = cancel_url
    end

    def call
      return failure("Unknown plan.") if @plan.nil?

      price_id = @plan.stripe_price_id
      if price_id.blank?
        return failure(
          "No Stripe price is configured for the #{@plan.name} plan. Set " \
          "stripe.prices.#{@plan.price_id} in Rails credentials."
        )
      end

      customer_id = ensure_customer
      return failure("Could not create a Stripe customer for this team.") if customer_id.blank?

      session = Stripe::Checkout::Session.create(checkout_params(customer_id, price_id))

      success(session)
    rescue Stripe::StripeError => e
      Sentry.capture_exception(e, extra: { team_id: @team.id })
      failure(e.message)
    end

    private

    def ensure_customer
      return @team.stripe_customer_id if @team.stripe_customer_id.present?

      result = Billing::CreateCustomer.call(team: @team)
      result.success? ? result.value : nil
    end

    def checkout_params(customer_id, price_id)
      {
        mode: "subscription",
        customer: customer_id,
        line_items: [ { price: price_id, quantity: @team.seat_count } ],
        success_url: @success_url,
        cancel_url: @cancel_url,
        client_reference_id: @team.id.to_s,
        # Carried onto the subscription so the webhook can find the team even if
        # the customer id has not been written locally yet.
        subscription_data: { metadata: { team_id: @team.id } },
        metadata: { team_id: @team.id },
        allow_promotion_codes: true
      }
    end
  end
end
