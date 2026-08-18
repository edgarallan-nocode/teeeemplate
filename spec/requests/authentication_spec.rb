# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Authentication" do
  describe "signing up" do
    it "creates an unconfirmed user and sends a confirmation email" do
      expect {
        post user_registration_path, params: {
          user: {
            first_name: "New", last_name: "Person",
            email: "new@example.com",
            password: "password1234", password_confirmation: "password1234"
          }
        }
      }.to change(User, :count).by(1)

      user = User.find_by(email: "new@example.com")
      expect(user.confirmed_at).to be_nil
      expect(enqueued_jobs.map { _1[:args].first }).to include("Users::DeviseMailer")
    end

    it "sends confirmation mail through Active Job, never inline" do
      expect {
        post user_registration_path, params: {
          user: { email: "async@example.com", password: "password1234",
                  password_confirmation: "password1234" }
        }
      }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    it "rejects a password below the minimum length" do
      post user_registration_path, params: {
        user: { email: "short@example.com", password: "short", password_confirmation: "short" }
      }

      expect(User.find_by(email: "short@example.com")).to be_nil
      expect(response.body).to include("stopped this from being saved")
    end
  end

  describe "signing in" do
    it "refuses an unconfirmed account" do
      user = create(:user, :unconfirmed)

      post user_session_path, params: { user: { email: user.email, password: "password1234" } }

      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "admits a confirmed account" do
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

  describe "confirming" do
    it "confirms with a valid token and then allows sign-in" do
      user = create(:user, :unconfirmed)
      token = user.send(:generate_confirmation_token)
      user.save!(validate: false)

      get user_confirmation_path(confirmation_token: token)

      expect(user.reload.confirmed_at).to be_present
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
