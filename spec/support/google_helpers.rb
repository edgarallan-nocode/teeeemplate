# frozen_string_literal: true

# Sign in with Google test support.
#
# OmniAuth's test mode short-circuits the trip to accounts.google.com: the
# request-phase POST redirects straight to the callback with `mock_auth` in
# the environment. Everything after that — the ID Google reported, what it means
# for the users table, where the browser is sent — runs for real. What is *not*
# exercised is the code exchange and token verification, which are the gem's,
# not ours.
module GoogleHelpers
  CLIENT_ID = "test-client-id.apps.googleusercontent.com"

  # Devise's mock auth hash for one Google account.
  def mock_google_sign_in(email:, uid: "google-uid-#{email}", first_name: "Googly", last_name: "Person")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: { email: email, first_name: first_name, last_name: last_name, name: "#{first_name} #{last_name}" }
    )
  end

  # Google said no: the person cancelled, or the exchange failed.
  def mock_google_failure(reason = :invalid_credentials)
    OmniAuth.config.mock_auth[:google_oauth2] = reason
  end

  # The request phase is POST-only, then the mock redirects to the callback.
  def sign_in_with_google
    post user_google_oauth2_omniauth_authorize_path
    follow_redirect!
  end

  # The button only renders with a client configured, and development and test
  # have none; a spec that looks for it sets one.
  def with_google_sign_in_enabled
    allow(Rails.configuration.x).to receive(:google_client_id).and_return(CLIENT_ID)
  end
end

OmniAuth.config.test_mode = true

RSpec.configure do |config|
  config.after { OmniAuth.config.mock_auth[:google_oauth2] = nil }
end
