# frozen_string_literal: true

module Teams
  class RemoveMember < ApplicationService
    def initialize(membership:)
      @membership = membership
      @user = membership.user
      @team = membership.team
    end

    def call
      return failure("A team must always have at least one owner.") if @membership.last_owner?

      unless @membership.destroy
        return failure(@membership.errors.full_messages.to_sentence.presence ||
                       "That member could not be removed.")
      end

      # If they were sitting in this team, point them somewhere they still
      # belong so their next request does not resolve to a team they left.
      clear_last_team

      TeamMailer.member_removed(@user, @team).deliver_later

      success(@membership)
    end

    private

    def clear_last_team
      return unless @user.last_team_id == @team.id

      @user.update_column(:last_team_id, @user.memberships.reload.first&.team_id)
    end
  end
end
