# frozen_string_literal: true

class TeamMailer < ApplicationMailer
  def invitation(invitation)
    @invitation = invitation
    @team = invitation.team
    @inviter = invitation.invited_by
    @accept_url = invitation_url(@invitation.token)

    mail to: @invitation.email,
         subject: "#{@inviter.name} invited you to join #{@team.name}"
  end

  def member_added(membership)
    @membership = membership
    @team = membership.team
    @user = membership.user

    mail to: @user.email, subject: "You've been added to #{@team.name}"
  end

  def member_removed(user, team)
    @user = user
    @team_name = team.name

    mail to: @user.email, subject: "You've been removed from #{@team_name}"
  end
end
