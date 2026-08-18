# frozen_string_literal: true

module Teams
  # Creating a team is three things that must happen together: the team, the
  # owner membership, and a Stripe customer. The first two are one transaction;
  # the third is deferred so a Stripe outage cannot stop someone signing up.
  class Create < ApplicationService
    def initialize(name:, owner:, slug: nil)
      @name = name
      @owner = owner
      @slug = slug
    end

    def call
      team = Team.new(name: @name, slug: @slug)

      ActiveRecord::Base.transaction do
        return failure_from(team) unless team.save

        Membership.create!(team: team, user: @owner, role: :owner)
        @owner.update_column(:last_team_id, team.id)
      end

      Billing::CreateCustomerJob.perform_later(team.id)

      success(team)
    end
  end
end
