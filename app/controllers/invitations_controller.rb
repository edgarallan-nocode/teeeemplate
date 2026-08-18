# frozen_string_literal: true

# Public invitation acceptance, reached from an email link.
#
# This is the one place a signed-out visitor legitimately touches team data, so
# it is deliberately narrow: the token looks up exactly one invitation, and the
# only thing you can do with it is accept it as the person it was addressed to.
class InvitationsController < ApplicationController
  skip_team_requirement!

  skip_before_action :authenticate_user!, only: :show
  skip_before_action :require_team

  before_action :set_invitation

  def show
    # Nothing team-scoped is authorized here: the visitor is by definition not
    # yet a member, and the token is the credential.
    skip_authorization

    if Current.user.nil?
      # Send them to sign in (or sign up) and come straight back here.
      store_location_for(:user, invitation_path(@invitation.token))
      redirect_to new_user_session_path,
                  notice: "Sign in as #{@invitation.email} to join #{@invitation.team.name}."
    end
  end

  def accept
    authorize @invitation, :accept?

    result = Teams::AcceptInvitation.call(invitation: @invitation, user: Current.user)

    if result.success?
      switch_to_team(@invitation.team)
      redirect_to dashboard_path, notice: "Welcome to #{@invitation.team.name}."
    else
      redirect_to invitation_path(@invitation.token), alert: result.error
    end
  end

  private

  def set_invitation
    @invitation = TeamInvitation.find_by!(token: params[:token] || params[:id])
  end
end
