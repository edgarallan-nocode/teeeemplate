# frozen_string_literal: true

module Users
  # Where Google sends the browser back. OmniAuth has already exchanged the code
  # and verified the ID token by the time this runs; what is left is deciding
  # what the identity means here, and Users::SignInWithGoogle decides that.
  #
  # Reached in two states. Signed out, it signs in or signs up. Signed in — from
  # the account page's Connect button — it attaches Google to the current account
  # and goes back there. The service tells the two apart by whether it was given
  # a user; this controller only routes the answer.
  class OmniauthCallbacksController < Devise::OmniauthCallbacksController
    skip_team_requirement!

    # Connecting Google to somebody else's account is not something support
    # staff do on their behalf.
    before_action :block_while_impersonating!, if: :user_signed_in?

    def google_oauth2
      result = Users::SignInWithGoogle.call(auth: request.env["omniauth.auth"], current_user: current_user)

      if result.failure?
        redirect_to failure_path, alert: result.error
      elsif user_signed_in?
        redirect_to account_path, notice: "Google is connected. You can sign in with it from now on."
      elsif result.value.previously_new_record?
        sign_up(result.value)
      else
        sign_in_and_redirect result.value, event: :authentication
      end
    end

    private

    # Lands where a password sign-up does, and honours a stored return path so
    # a person who arrived from an invitation link goes back to it.
    def sign_up(user)
      sign_in(user, event: :authentication)
      redirect_to stored_location_for(user) || dashboard_path, notice: "Welcome. Your account is ready."
    end

    def failure_path
      user_signed_in? ? account_path : new_user_session_path
    end

    # Devise's failure action lands here when Google itself said no — the person
    # cancelled, or the exchange failed.
    def after_omniauth_failure_path_for(_scope) = failure_path
  end
end
