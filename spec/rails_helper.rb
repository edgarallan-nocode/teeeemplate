# frozen_string_literal: true

require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "capybara/rspec"
require "webmock/rspec"

# Every request to the outside world must be explicitly stubbed. A spec that
# accidentally calls Stripe should fail loudly, not quietly hit the network.
WebMock.disable_net_connect!(allow_localhost: true)

Rails.root.glob("spec/support/**/*.rb").sort.each { |f| require f }

# Rails 8 draws routes lazily, and Devise builds its mappings while they are
# drawn. Without this, the first `sign_in` in a spec run fails with
# "Could not find a valid mapping" purely because no route helper has been
# touched yet.
Rails.application.reload_routes_unless_loaded

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include AuthenticationHelpers
  config.include TenancyHelpers
  config.include StripeHelpers

  # Job assertions (have_enqueued_job, perform_enqueued_jobs) are useful in
  # model and service specs too, not only in request specs.
  config.include ActiveJob::TestHelper

  # Current is request-scoped in the app; in specs it has to be reset by hand or
  # state leaks between examples and hides tenant-scoping bugs.
  config.before { Current.reset }
  config.after  { Current.reset }

  config.before(:each, type: :system) { driven_by :rack_test }
  config.before(:each, :js, type: :system) { driven_by :selenium_chrome_headless }
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
