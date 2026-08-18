# frozen_string_literal: true

# Request-scoped state. Set once per request in ApplicationController and reset
# automatically by Rails between requests.
#
# `user` is who the application is acting as. `true_user` is who is actually
# signed in — they differ only during admin impersonation, and every audit trail
# records both.
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :true_user, :team, :membership
  attribute :request_id, :ip_address, :user_agent

  def impersonating?
    true_user.present? && true_user != user
  end

  # Convenience for models that need to attribute a change without reaching for
  # the controller.
  def user_id = user&.id
  def team_id = team&.id
end
