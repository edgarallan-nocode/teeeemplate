# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def show
      skip_authorization

      @user_count = User.count
      @team_count = Team.count
      @membership_count = Membership.count
      @active_subscriptions = Subscription.entitled.count
      @seats_billed = Subscription.entitled.sum(:quantity)
      @failed_events = StripeEvent.failed.count
      @recent_impersonations = ImpersonationEvent.recent.includes(:admin, :user).limit(5)
      @recent_teams = Team.order(created_at: :desc).limit(5)
    end
  end
end
