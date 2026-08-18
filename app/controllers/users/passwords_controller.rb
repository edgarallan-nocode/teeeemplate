# frozen_string_literal: true

module Users
  class PasswordsController < Devise::PasswordsController
    skip_team_requirement!

    layout "application"
  end
end
