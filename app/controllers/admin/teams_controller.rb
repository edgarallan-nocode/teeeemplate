# frozen_string_literal: true

module Admin
  class TeamsController < BaseController
    def index
      @teams = policy_scope(
        Team.search(params[:q])
            .left_joins(:subscription)
            .includes(:subscription)
            .order(created_at: :desc),
        policy_scope_class: Admin::BasePolicy::Scope
      )
      @page = paginate(@teams)
    end

    def show
      # Team#to_param is the slug, so admin links carry a slug too.
      @team = Team.find_by!(slug: params[:id])
      authorize @team, policy_class: Admin::TeamPolicy

      @memberships = @team.memberships.ordered.includes(:user)
      @invitations = @team.invitations.order(created_at: :desc).limit(20)
      @subscription = @team.subscription
      @project_count = @team.projects.count
    end
  end
end
