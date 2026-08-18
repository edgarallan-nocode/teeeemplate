# frozen_string_literal: true

module Teams
  # Leaving a team is a member acting on themselves, which is why it is separate
  # from RemoveMember even though the mechanics overlap — the authorization
  # question is different, and so is the follow-up.
  class Leave < ApplicationService
    def initialize(team:, user:)
      @team = team
      @user = user
      @membership = user.memberships.find_by(team: team)
    end

    def call
      return failure("You are not a member of that team.") if @membership.nil?

      if @membership.last_owner?
        return failure(
          "You are the only owner of #{@team.name}. Promote another owner, or " \
          "delete the team instead."
        )
      end

      return failure("You could not be removed from that team.") unless @membership.destroy

      @user.update_column(:last_team_id, @user.memberships.reload.first&.team_id)

      success(@team)
    end
  end
end
