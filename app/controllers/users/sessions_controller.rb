# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    skip_team_requirement!

    layout "application"

    # Any impersonation must not survive a sign-out.
    def destroy
      session.delete(:impersonated_user_id)
      Admin::StopImpersonation.call(event_id: session.delete(:impersonation_event_id))
      super
    end
  end
end
