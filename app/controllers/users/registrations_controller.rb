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

    # Accounts are active immediately, so a new user is signed in and sent
    # straight to team creation by the dashboard's team requirement.
    def after_sign_up_path_for(_resource) = dashboard_path
  end
end
