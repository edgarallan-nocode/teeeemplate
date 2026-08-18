# frozen_string_literal: true

module Billing
  # The Stripe Customer Portal handles cards, invoices, plan changes and
  # cancellation. Reimplementing any of that would mean reimplementing PCI
  # scope along with it.
  class CreatePortalSession < ApplicationService
    def initialize(team:, return_url:)
      @team = team
      @return_url = return_url
    end

    def call
      if @team.stripe_customer_id.blank?
        return failure("This team does not have a billing account yet.")
      end

      session = Stripe::BillingPortal::Session.create(
        customer: @team.stripe_customer_id,
        return_url: @return_url
      )

      success(session)
    rescue Stripe::StripeError => e
      Sentry.capture_exception(e, extra: { team_id: @team.id })
      failure(e.message)
    end
  end
end
