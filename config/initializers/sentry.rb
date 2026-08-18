# frozen_string_literal: true

# Sentry is only wired up when a DSN is present, so development and CI stay
# quiet without needing a separate flag.
dsn = Rails.application.credentials.dig(:sentry, :dsn) || ENV["SENTRY_DSN"]

Sentry.init do |config|
  config.dsn = dsn
  config.enabled_environments = %w[production staging]
  config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
  config.breadcrumbs_logger = %i[active_support_logger http_logger]
  config.send_default_pii = false

  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f

  # Never let secrets reach Sentry, even accidentally.
  config.before_send = lambda do |event, _hint|
    event.request&.data = nil
    event
  end
end if dsn.present?
