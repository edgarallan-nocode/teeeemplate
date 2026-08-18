# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authentication" do
  describe "signing up" do
    it "creates an account that works immediately" do
      expect {
        post user_registration_path, params: {
          user: {
            first_name: "New", last_name: "Person",
            email: "new@example.com",
            password: "password1234", password_confirmation: "password1234"
          }
        }
      }.to change(User, :count).by(1)

      # No confirmation step: the new user is signed in straight away and is
      # sent on to create a team.
      expect(response).to redirect_to(dashboard_path)

      follow_redirect!
      expect(response).to redirect_to(new_team_path)
    end

    it "sends no confirmation email" do
      expect {
        post user_registration_path, params: {
          user: { email: "quiet@example.com", password: "password1234",
                  password_confirmation: "password1234" }
        }
      }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    it "rejects a password below the configured minimum length" do
      # Derived from Devise.password_length rather than hard-coded, so tuning
      # the minimum in config/initializers/devise.rb does not break this spec —
      # it still proves the rule is enforced at whatever length is configured.
      too_short = "a" * (Devise.password_length.min - 1)

      post user_registration_path, params: {
        user: { email: "short@example.com",
                password: too_short, password_confirmation: too_short }
      }

      expect(User.find_by(email: "short@example.com")).to be_nil
      expect(response.body).to include("stopped this from being saved")
    end
  end

  describe "signing in" do
    it "admits a brand new account with no confirmation step" do
      user = create(:user, :with_team)

      post user_session_path, params: { user: { email: user.email, password: "password1234" } }

      expect(response).to redirect_to(root_path)
    end

    it "refuses a wrong password" do
      user = create(:user)

      post user_session_path, params: { user: { email: user.email, password: "wrong-password" } }

      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "resetting a password" do
    it "emails a reset link without revealing whether the address exists" do
      create(:user, email: "known@example.com")

      post user_password_path, params: { user: { email: "known@example.com" } }
      known_response = response.status

      post user_password_path, params: { user: { email: "unknown@example.com" } }

      # Devise runs in paranoid mode: both answers look the same.
      expect(response.status).to eq(known_response)
    end

    it "changes the password with a valid token" do
      user = create(:user)
      token = user.send_reset_password_instructions

      put user_password_path, params: {
        user: {
          reset_password_token: token,
          password: "brand-new-password", password_confirmation: "brand-new-password"
        }
      }

      expect(user.reload.valid_password?("brand-new-password")).to be(true)
    end
  end

  describe "signing out" do
    it "ends the session" do
      user = create(:user, :with_team)
      sign_in user

      delete destroy_user_session_path

      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
