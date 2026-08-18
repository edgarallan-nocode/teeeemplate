# frozen_string_literal: true

module Billing
  # Creates the team's Stripe Customer out of band, so signing up never waits on
  # Stripe and a Stripe outage cannot block team creation.
  class CreateCustomerJob < ApplicationJob
    queue_as :default

    retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5
    retry_on Stripe::APIConnectionError, wait: :polynomially_longer, attempts: 5

    def perform(team_id)
      team = Team.find_by(id: team_id)
      return if team.nil?

      Billing::CreateCustomer.call(team: team)
    end
  end
end
