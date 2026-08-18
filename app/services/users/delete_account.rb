# frozen_string_literal: true

module Users
  # Account deletion.
  #
  # Refuses when the user is the only owner of a team that other people are
  # still using — deleting them would leave that team with nobody who can manage
  # billing or membership. The user is told exactly which teams block them and
  # what to do about it, rather than getting a generic failure.
  class DeleteAccount < ApplicationService
    def initialize(user:, password:)
      @user = user
      @password = password
    end

    def call
      return failure("That password is incorrect.") unless @user.valid_password?(@password)

      blocking = blocking_teams
      return failure(blocking_message(blocking)) if blocking.any?

      ActiveRecord::Base.transaction do
        # Teams this user solely owns and nobody else is in have no reason to
        # outlive the account.
        solo_teams.each(&:destroy!)
        @user.destroy!
      end

      success(@user)
    end

    private

    # Teams where this user is the only owner AND other people are members.
    def blocking_teams
      sole_owner_teams.select { |team| team.memberships.count > 1 }
    end

    # Teams where this user is the only owner and the only member.
    def solo_teams
      sole_owner_teams.select { |team| team.memberships.count == 1 }
    end

    def sole_owner_teams
      @sole_owner_teams ||= @user.memberships.owner.includes(:team).filter_map do |membership|
        membership.team if membership.team.memberships.owner.count == 1
      end
    end

    def blocking_message(teams)
      names = teams.map(&:name).to_sentence

      "You are the only owner of #{names}. Promote another owner or delete " \
      "#{'that team'.pluralize(teams.size)} before deleting your account."
    end
  end
end
