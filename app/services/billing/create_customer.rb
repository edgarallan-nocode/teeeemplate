# frozen_string_literal: true

module Billing
  # Creates the Stripe Customer for a team, exactly once.
  #
  # Two layers of protection against duplicates: the local
  # `stripe_customer_id` short-circuits, and an idempotency key derived from
  # the team id makes a retried request return the original customer rather
  # than creating a second one.
  class CreateCustomer < ApplicationService
    def initialize(team:)
      @team = team
    end

    def call
      return success(@team.stripe_customer_id) if @team.stripe_customer_id.present?

      customer = Stripe::Customer.create(
        {
          name: @team.name,
          email: @team.owners.first&.email,
          metadata: { team_id: @team.id, team_slug: @team.slug }
        },
        { idempotency_key: "team-customer-#{@team.id}" }
      )

      @team.update!(stripe_customer_id: customer.id)

      success(customer.id)
    rescue Stripe::StripeError => e
      Sentry.capture_exception(e, extra: { team_id: @team.id })
      failure(e.message)
    end
  end
end
