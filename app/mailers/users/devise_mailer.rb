# frozen_string_literal: true

module Users
  # Devise's mailer, re-pointed at this application's layout and templates so
  # confirmation and reset emails look like the rest of the product rather than
  # like a gem's defaults.
  class DeviseMailer < ApplicationMailer
    include Devise::Mailers::Helpers

    def reset_password_instructions(record, token, opts = {})
      @token = token
      devise_mail(record, :reset_password_instructions, opts)
    end

    def email_changed(record, opts = {})
      devise_mail(record, :email_changed, opts)
    end

    def password_change(record, opts = {})
      devise_mail(record, :password_change, opts)
    end
  end
end
