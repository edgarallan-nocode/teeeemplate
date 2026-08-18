# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.configuration.x.mailer_from }
  layout "mailer"

  helper :application

  private

  # Every mailer template links back into the app, so they all need this.
  def default_url_options
    super.merge(
      host: Rails.configuration.x.app_host,
      protocol: Rails.configuration.x.app_protocol
    )
  end
end
