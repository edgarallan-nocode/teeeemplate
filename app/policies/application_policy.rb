# frozen_string_literal: true

# Base for every policy.
#
# Policies answer one question: may this user perform this action on this
# record? They do NOT decide which records are visible — tenant scoping already
# did that by starting the query from Current.team. See TenantScoped.
#
# Role logic belongs here and nowhere else. If a controller or view is asking
# `membership.owner?` directly, that check has escaped its policy.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?   = membership.present?
  def show?    = membership.present?
  def create?  = admin_or_above?
  def new?     = create?
  def update?  = admin_or_above?
  def edit?    = update?
  def destroy? = admin_or_above?

  # The current user's membership in the active team. Policies read roles from
  # here rather than from the record, so a policy works the same whether the
  # record is a Project or the Team itself.
  def membership = Current.membership

  def owner?  = membership&.owner? || false
  def admin_or_above? = membership&.admin_or_above? || false
  def member? = membership.present?

  # Platform staff. Deliberately unrelated to team roles.
  def platform_admin? = user&.admin? || false

  def impersonating? = Current.impersonating?

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # Scopes start from the relation the controller already scoped to
    # Current.team. This is the second gate, not the first.
    def resolve
      return scope.none if Current.membership.nil?

      scope.all
    end

    private

    def membership = Current.membership
  end
end
