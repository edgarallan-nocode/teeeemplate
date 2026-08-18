# frozen_string_literal: true

class DashboardController < ApplicationController
  def show
    authorize current_team, :show?, policy_class: TeamPolicy

    # Everything here starts from the team, not from the model class.
    @projects = policy_scope(current_team.projects.active.recent.limit(5))
    @members = current_team.memberships.ordered.includes(:user).limit(8)
    @pending_invitations = current_team.invitations.pending.count
  end
end
