# frozen_string_literal: true

# Populates Current for the request. Runs before team resolution so that
# Current.user is available when the active team is looked up.
module SetsCurrentAttributes
  extend ActiveSupport::Concern

  included do
    before_action :set_current_attributes
  end

  private

  def set_current_attributes
    Current.request_id = request.request_id
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent

    # true_user is who actually signed in; user is who we are acting as. They
    # are the same unless an admin is impersonating.
    Current.true_user = current_user
    Current.user = impersonated_user || current_user
  end
end
