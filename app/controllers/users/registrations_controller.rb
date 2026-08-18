# frozen_string_literal: true

module Users
  # Devise's registrations, subclassed only so sign-up renders in the
  # application layout with the rest of the design system.
  #
  # Account updates and deletion are handled by AccountController, not here, so
  # they can require a password and run through Users::DeleteAccount.
  class RegistrationsController < Devise::RegistrationsController
    skip_team_requirement!

    layout "application"

    private

    def after_inactive_sign_up_path_for(_resource)
      # Confirmation is required before sign-in, so land somewhere that explains
      # what happens next rather than bouncing to a login form.
      new_user_session_path
    end

    def after_sign_up_path_for(_resource) = dashboard_path
  end
end
