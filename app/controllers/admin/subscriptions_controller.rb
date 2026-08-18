# frozen_string_literal: true

module Admin
  class SubscriptionsController < BaseController
    def index
      scope = Subscription.includes(:team).order(created_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?

      @subscriptions = policy_scope(scope, policy_scope_class: Admin::BasePolicy::Scope)
      @page = paginate(@subscriptions)
      @statuses = Subscription::STATUSES
    end
  end
end
