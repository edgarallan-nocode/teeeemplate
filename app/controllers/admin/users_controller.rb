# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    def index
      @users = policy_scope(
        User.search(params[:q]).order(created_at: :desc),
        policy_scope_class: Admin::BasePolicy::Scope
      )
      @page = paginate(@users)
    end

    def show
      @user = User.find(params[:id])
      authorize @user, policy_class: Admin::UserPolicy

      @memberships = @user.memberships.includes(:team).ordered
      @impersonations = @user.impersonation_events.recent.includes(:admin).limit(10)
    end
  end
end
