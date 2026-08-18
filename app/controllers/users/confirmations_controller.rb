# frozen_string_literal: true

module Users
  class ConfirmationsController < Devise::ConfirmationsController
    skip_team_requirement!

    layout "application"

    private

    def after_confirmation_path_for(_resource_name, _resource)
      new_user_session_path
    end
  end
end
