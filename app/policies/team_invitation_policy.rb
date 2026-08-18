# frozen_string_literal: true

class TeamInvitationPolicy < ApplicationPolicy
  def index? = admin_or_above?

  def create? = admin_or_above?

  def destroy? = admin_or_above?

  # Only an owner may invite someone straight in as an owner.
  def invitable_roles
    return Membership.roles.keys if owner?
    return %w[member admin] if admin_or_above?

    []
  end

  # Accepting is not a team-scoped action — the accepting user is by definition
  # not yet a member — so it is authorized against the invitation itself.
  def accept?
    return false if user.nil?
    return false unless record.pending?

    record.email == user.email
  end

  def show? = accept?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless membership&.admin_or_above?

      scope.all
    end
  end
end
