# frozen_string_literal: true

# Admin support impersonation.
#
# Safety rails, all enforced here or in Admin::ImpersonationsController:
#   * only a platform admin may start one
#   * admins can never be impersonated
#   * every start and stop writes an ImpersonationEvent
#   * a banner is always visible while impersonating
#   * dangerous actions are refused outright (see `block_while_impersonating!`)
module Impersonation
  extend ActiveSupport::Concern

  included do
    helper_method :impersonating?, :true_user, :impersonated_user
  end

  # Actions that must never run while impersonating. Support staff can look at
  # an account; they cannot spend the customer's money or destroy their data.
  def block_while_impersonating!
    return unless impersonating?

    redirect_back fallback_location: root_path,
                  alert: "That action is not available while impersonating a user."
  end

  private

  def impersonating? = impersonated_user.present?

  def true_user = current_user

  def impersonated_user
    return @impersonated_user if defined?(@impersonated_user)

    @impersonated_user = resolve_impersonated_user
  end

  def resolve_impersonated_user
    id = session[:impersonated_user_id]
    return nil if id.blank?

    # Re-check authority on every request, not just when impersonation starts.
    # If the admin flag is revoked mid-session, impersonation ends immediately.
    unless current_user&.admin?
      session.delete(:impersonated_user_id)
      session.delete(:impersonation_event_id)
      return nil
    end

    target = User.find_by(id: id)

    # An admin may never be impersonated, and a deleted user cannot be.
    if target.nil? || target.admin?
      session.delete(:impersonated_user_id)
      session.delete(:impersonation_event_id)
      return nil
    end

    target
  end
end
