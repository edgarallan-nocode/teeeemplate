# frozen_string_literal: true

module Billing
  # Keeps the Stripe subscription quantity equal to the team's member count.
  #
  # Idempotent by construction: it reads the current member count from the
  # database and compares it to the current quantity, so running it twice is a
  # no-op rather than a double increment.
  class SyncSeatsJob < ApplicationJob
    queue_as :default

    retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5
    retry_on Stripe::APIConnectionError, wait: :polynomially_longer, attempts: 5

    # A team deleted between enqueue and run has nothing to sync.
    discard_on ActiveRecord::RecordNotFound

    def perform(team_id)
      team = Team.find_by(id: team_id)
      return if team.nil?

      Billing::SyncSeats.call(team: team)
    end
  end
end
