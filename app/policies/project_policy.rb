# frozen_string_literal: true

# EXAMPLE POLICY — pairs with the example Project model.
#
# Note what it does NOT do: it never checks `record.team == Current.team`. By
# the time a policy runs, the controller has already loaded the record through
# Current.team, so a record from another team never reaches here. Re-checking
# would imply the scoping is untrustworthy.
class ProjectPolicy < ApplicationPolicy
  def index? = member?
  def show? = member?

  # Any member may create and edit project content; destroying is a permanent
  # loss, so it takes an admin.
  def create? = member?
  def update? = member?
  def destroy? = admin_or_above?
  def archive? = member?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if membership.nil?

      scope.all
    end
  end
end
