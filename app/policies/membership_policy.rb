# frozen_string_literal: true

class MembershipPolicy < ApplicationPolicy
  def index? = member?

  # Roles are granted by admins, but only an owner may create another owner —
  # otherwise an admin could promote themselves past their own ceiling.
  def update?
    return false unless admin_or_above?
    return false if record.last_owner?
    return false if targeting_self?

    owner? || !record.owner?
  end

  # An admin may remove members, but not owners; owners can remove anyone.
  def destroy?
    return false unless admin_or_above?
    return false if record.last_owner?
    return true if targeting_self? # leaving is handled by TeamPolicy#leave?

    owner? || !record.owner?
  end

  # Which roles the current user is allowed to assign. Used by the form so the
  # UI cannot offer an option the policy would reject.
  def assignable_roles
    return Membership.roles.keys if owner?
    return %w[member admin] if admin_or_above?

    []
  end

  def create? = admin_or_above?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if membership.nil?

      scope.all
    end
  end

  private

  def targeting_self? = record.user_id == user&.id
end
