# frozen_string_literal: true

require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Teeeemplate
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.time_zone = "UTC"

    # Generators: RSpec only, no fixtures, no helper/asset cruft.
    config.generators do |g|
      g.test_framework :rspec,
                       fixtures: false,
                       view_specs: false,
                       helper_specs: false,
                       routing_specs: false
      g.helper false
      g.system_tests = nil
    end

    # Background work goes through Active Job -> Sidekiq. Everything that can be
    # deferred is deferred, including all mail.
    config.active_job.queue_adapter = :sidekiq

    # Application-wide host, used by mailers and anything building absolute URLs.
    config.x.app_host     = ENV.fetch("APP_HOST", "localhost:3000")
    config.x.app_protocol = ENV.fetch("APP_PROTOCOL", "http")
    config.x.mailer_from  = ENV.fetch("MAILER_FROM", "noreply@example.com")
    config.x.support_email = ENV.fetch("SUPPORT_EMAIL", "support@example.com")
  end
end
