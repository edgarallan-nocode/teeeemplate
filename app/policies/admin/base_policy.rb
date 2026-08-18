# frozen_string_literal: true

module Admin
  # Platform administration is gated on the user's `admin` flag alone. It is
  # deliberately unrelated to team roles: being an owner of your own team grants
  # nothing here, and being a platform admin grants no extra power inside a team
  # you do not belong to.
  class BasePolicy < ApplicationPolicy
    def index?   = platform_admin?
    def show?    = platform_admin?
    def create?  = platform_admin?
    def update?  = platform_admin?
    def destroy? = platform_admin?

    class Scope < ApplicationPolicy::Scope
      def resolve
        return scope.none unless user&.admin?

        scope.all
      end
    end
  end
end
