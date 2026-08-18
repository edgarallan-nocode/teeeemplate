# frozen_string_literal: true

class TeamPolicy < ApplicationPolicy
  # Anyone signed in may create a team of their own.
  def create? = user.present?
  def new? = create?

  def show? = member?

  # Team settings — name, slug — are an admin concern.
  def update? = admin_or_above?
  def edit? = update?

  # Deleting a team destroys everyone's data in it and cancels billing, so it is
  # owners only, and never while impersonating.
  def destroy? = owner? && !impersonating?

  def switch?
    user.present? && user.member_of?(record)
  end

  # Leaving is always allowed unless it would strand the team without an owner.
  def leave?
    return false if membership.nil?

    !membership.last_owner?
  end
end
