# frozen_string_literal: true

module Teams
  class MembersController < ApplicationController
    before_action :set_team
    before_action :set_membership, only: %i[update destroy]

    def index
      @memberships = policy_scope(@team.memberships.ordered.includes(:user))
      @invitations = @team.invitations.pending.order(created_at: :desc)
      @invitation = @team.invitations.build
    end

    def update
      authorize @membership

      result = ::Teams::ChangeRole.call(membership: @membership, role: params[:membership][:role])

      if result.success?
        redirect_to team_members_path(@team),
                    notice: "#{@membership.user.name} is now #{@membership.role_label}."
      else
        redirect_to team_members_path(@team), alert: result.error
      end
    end

    def destroy
      authorize @membership

      result = ::Teams::RemoveMember.call(membership: @membership)

      if result.success?
        redirect_to team_members_path(@team),
                    notice: "#{@membership.user.name} was removed.",
                    status: :see_other
      else
        redirect_to team_members_path(@team), alert: result.error, status: :see_other
      end
    end

    private

    # The URL decides which team we are operating on, not the session.
    def set_team
      @team = set_team_from_params
    end

    # Scoped to the team, so a membership id from another team is not found.
    def set_membership
      @membership = @team.memberships.find(params[:id])
    end
  end
end
