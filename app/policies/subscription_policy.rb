# frozen_string_literal: true

class SubscriptionPolicy < ApplicationPolicy
  # Seeing what the team pays is reasonable for admins; changing it is not.
  def show? = admin_or_above?

  # Money movement is owners only, and never while impersonating — support
  # staff must not be able to start a subscription on a customer's card.
  def checkout? = owner? && !impersonating?
  def portal?   = owner? && !impersonating?
  def cancel?   = owner? && !impersonating?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless membership&.admin_or_above?

      scope.all
    end
  end
end
