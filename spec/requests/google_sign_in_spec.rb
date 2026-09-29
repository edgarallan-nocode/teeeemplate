# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sign in with Google" do
  describe "the button" do
    it "is absent until a Google client is configured" do
      get new_user_session_path
      expect(response.body).not_to include("Continue with Google")

      get new_user_registration_path
      expect(response.body).not_to include("Continue with Google")
    end

    it "appears on sign-in and sign-up once one is" do
      with_google_sign_in_enabled

      get new_user_session_path
      expect(response.body).to include("Continue with Google")

      get new_user_registration_path
      expect(response.body).to include("Continue with Google")
    end

    it "is only reachable by POST" do
      # OmniAuth 2's request phase is POST-only, so a link on another site cannot
      # start the flow, and the form token on that POST is what
      # omniauth-rails_csrf_protection checks. Devise draws no GET route at all.
      expect { get user_google_oauth2_omniauth_authorize_path }.to raise_error(ActionController::RoutingError)
    end
  end

  describe "signing up" do
    it "creates an account from the Google profile and signs it in" do
      mock_google_sign_in(email: "new@example.com", uid: "g-1", first_name: "Ada", last_name: "Lovelace")

      expect { sign_in_with_google }.to change(User, :count).by(1)

      user = User.find_by!(email: "new@example.com")
      expect(user.google_uid).to eq("g-1")
      expect(user.first_name).to eq("Ada")
      expect(user.last_name).to eq("Lovelace")

      # Same landing as a password sign-up: straight in, on to team creation.
      expect(response).to redirect_to(dashboard_path)
      follow_redirect!
      expect(response).to redirect_to(new_team_path)
    end

    it "sends no email" do
      mock_google_sign_in(email: "quiet@example.com")

      expect { sign_in_with_google }.not_to have_enqueued_job(ActionMailer::MailDeliveryJob)
    end

    it "returns to a stored invitation, like a password sign-up does" do
      invitation = create(:team_invitation, email: "invited@example.com")
      get invitation_path(invitation.token)
      expect(response).to redirect_to(new_user_session_path)

      mock_google_sign_in(email: "invited@example.com")
      sign_in_with_google

      expect(response).to redirect_to(invitation_path(invitation.token))
    end
  end

  describe "signing in" do
    it "admits a user whose Google account is connected" do
      user = create(:user, :with_team, google_uid: "g-known")
      mock_google_sign_in(email: user.email, uid: "g-known")

      sign_in_with_google

      expect(response).to redirect_to(root_path)
      get dashboard_path
      expect(response).to have_http_status(:ok)
    end

    it "matches on the Google id, not the email address" do
      # The address on the Google account may change; the subject id does not.
      user = create(:user, :with_team, email: "old@example.com", google_uid: "g-stable")
      mock_google_sign_in(email: "renamed@example.com", uid: "g-stable")

      expect { sign_in_with_google }.not_to change(User, :count)

      expect(response).to redirect_to(root_path)
      expect(user.reload.email).to eq("old@example.com")
    end

    it "refuses to attach itself to an existing account by email alone" do
      # Addresses are unverified (SKILL.md §2a): the account could be anybody's
      # claim on that address, waiting for its real owner to walk in.
      create(:user, email: "taken@example.com")
      mock_google_sign_in(email: "taken@example.com", uid: "g-new")

      expect { sign_in_with_google }.not_to change(User, :count)

      expect(response).to redirect_to(new_user_session_path)
      expect(flash[:alert]).to include("connect Google from your account page")
      expect(User.find_by(email: "taken@example.com").google_uid).to be_nil

      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "goes back to the sign-in page when Google says no" do
      mock_google_failure

      sign_in_with_google

      expect(response).to redirect_to(new_user_session_path)
      get dashboard_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "connecting from the account page" do
    let(:user) { create(:user, :with_team) }

    before { sign_in user }

    it "attaches the Google account to the signed-in user" do
      mock_google_sign_in(email: "anything@example.com", uid: "g-mine")

      sign_in_with_google

      expect(response).to redirect_to(account_path)
      expect(user.reload.google_uid).to eq("g-mine")
    end

    it "refuses a Google account another user already connected" do
      create(:user, google_uid: "g-theirs")
      mock_google_sign_in(email: user.email, uid: "g-theirs")

      sign_in_with_google

      expect(response).to redirect_to(account_path)
      expect(flash[:alert]).to include("already connected")
      expect(user.reload.google_uid).to be_nil
    end

    it "shows Connect before and Disconnect after" do
      with_google_sign_in_enabled

      get account_path
      expect(response.body).to include("Connect Google")

      user.update!(google_uid: "g-mine")
      get account_path
      expect(response.body).to include("Disconnect Google")
    end
  end

  describe "disconnecting" do
    let(:user) { create(:user, :with_team, google_uid: "g-mine") }

    before { sign_in user }

    it "requires the password, since it becomes the only way in" do
      delete google_account_path, params: { current_password: "wrong" }
      expect(user.reload.google_uid).to eq("g-mine")

      delete google_account_path, params: { current_password: "password1234" }
      expect(user.reload.google_uid).to be_nil
      expect(response).to redirect_to(account_path)
    end
  end
end
