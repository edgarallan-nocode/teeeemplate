# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

# ---------------------------------------------------------------------------
# Framework
# ---------------------------------------------------------------------------
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "propshaft"                       # asset pipeline
gem "pg", "~> 1.1"
gem "puma", ">= 6.0"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

# ---------------------------------------------------------------------------
# Frontend — server-rendered Rails. No SPA, no Tailwind, no React/Vue.
# ---------------------------------------------------------------------------
gem "turbo-rails"
gem "stimulus-rails"
gem "jsbundling-rails"                # esbuild
gem "cssbundling-rails"               # dart-sass

# ---------------------------------------------------------------------------
# Authentication & authorization
# ---------------------------------------------------------------------------
gem "devise", "~> 5.0"
gem "pundit", "~> 2.5"
gem "bcrypt", "~> 3.1"

# ---------------------------------------------------------------------------
# Background work
# ---------------------------------------------------------------------------
gem "sidekiq", "~> 8.0"
gem "redis", ">= 5.0"

# ---------------------------------------------------------------------------
# Billing
# ---------------------------------------------------------------------------
gem "stripe", "~> 19.0"

# ---------------------------------------------------------------------------
# AWS — SES for mail, S3 for Active Storage.
# Credentials come from the EC2 instance IAM role, never from static keys.
# ---------------------------------------------------------------------------
gem "aws-actionmailer-ses", "~> 1.0"
gem "aws-sdk-s3", require: false
gem "image_processing", "~> 1.2"

# ---------------------------------------------------------------------------
# Observability
# ---------------------------------------------------------------------------
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails"
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "faker"
end

group :development do
  gem "web-console"
  gem "letter_opener_web", "~> 3.0"
  gem "annotaterb"
  gem "foreman"

  # Quality gates. The committed config files are the source of truth;
  # editor integrations only mirror them.
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", require: false
  gem "brakeman", require: false
  gem "bundler-audit", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers", "~> 6.0"
  gem "webmock"
  gem "simplecov", require: false
end
