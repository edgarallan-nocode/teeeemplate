# frozen_string_literal: true

module Teams
  class InvitationsController < ApplicationController
    before_action :set_team

    def index
      @invitations = policy_scope(@team.invitations.order(created_at: :desc))
    end

    def create
      authorize TeamInvitation

      result = ::Teams::InviteMember.call(
        team: @team,
        email: invitation_params[:email],
        role: invitation_params[:role],
        invited_by: Current.user
      )

      if result.success?
        redirect_to team_members_path(@team),
                    notice: "Invitation sent to #{result.value.email}."
      else
        redirect_to team_members_path(@team), alert: result.error
      end
    end

    def destroy
      invitation = @team.invitations.find(params[:id])
      authorize invitation

      invitation.destroy!

      redirect_to team_members_path(@team),
                  notice: "Invitation to #{invitation.email} was revoked.",
                  status: :see_other
    end

    private

    # The URL decides which team we are operating on, not the session.
    def set_team
      @team = set_team_from_params
    end

    def invitation_params
      params.expect(team_invitation: %i[email role])
    end
  end
end
