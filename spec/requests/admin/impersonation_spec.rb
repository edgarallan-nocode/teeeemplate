# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Impersonation" do
  let(:platform_admin) { create(:user, :admin) }
  let(:tenant) { create_tenant }
  let(:target) { tenant.owner }

  def start_impersonating(user = target)
    post admin_impersonations_path, params: { user_id: user.id }
  end

  describe "starting" do
    before { sign_in platform_admin }

    it "records an audit event with who, whom, and from where" do
      expect { start_impersonating }.to change(ImpersonationEvent, :count).by(1)

      event = ImpersonationEvent.last
      expect(event.admin).to eq(platform_admin)
      expect(event.user).to eq(target)
      expect(event.started_at).to be_present
      expect(event.ip_address).to be_present
      expect(event).to be_active
    end

    it "acts as the target from then on" do
      start_impersonating
      get dashboard_path

      expect(response.body).to include(html(tenant.team.name))
    end

    it "shows a banner naming both people" do
      start_impersonating
      get dashboard_path

      expect(response.body).to include("Impersonating")
      expect(response.body).to include(html(target.name))
      expect(response.body).to include(html(platform_admin.name))
    end

    it "refuses to impersonate another platform admin" do
      other_admin = create(:user, :admin)

      expect { start_impersonating(other_admin) }.not_to change(ImpersonationEvent, :count)
      expect(session[:impersonated_user_id]).to be_nil
    end

    it "refuses to impersonate yourself" do
      expect { start_impersonating(platform_admin) }.not_to change(ImpersonationEvent, :count)
    end

    it "refuses to start a second impersonation without stopping the first" do
      start_impersonating
      first = ImpersonationEvent.last

      # The admin area is closed while impersonating, so there is no route to a
      # second start. You must stop first.
      expect { start_impersonating(tenant.member) }
        .not_to change(ImpersonationEvent, :count)

      expect(first.reload).to be_active
    end
  end

  describe "what impersonation cannot do" do
    before do
      sign_in platform_admin
      start_impersonating
    end

    it "cannot start a checkout" do
      post checkout_billing_subscription_path(plan: "starter")

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to be_present
    end

    it "cannot open the Stripe billing portal" do
      post portal_billing_subscription_path

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to be_present
    end

    it "cannot delete the impersonated user's account" do
      expect {
        delete account_path, params: { current_password: "password1234" }
      }.not_to change(User, :count)
    end

    it "cannot delete the team" do
      delete team_path(tenant.team)

      expect(Team.exists?(tenant.team.id)).to be(true)
    end

    it "cannot re-enter the admin area" do
      get admin_root_path

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to match(/stop impersonating/i)
    end

    it "can still read the product" do
      get dashboard_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "stopping" do
    before do
      sign_in platform_admin
      start_impersonating
    end

    it "closes the audit event and returns the admin to themselves" do
      delete admin_stop_impersonation_path

      expect(ImpersonationEvent.last.reload).not_to be_active
      expect(session[:impersonated_user_id]).to be_nil

      get admin_root_path
      expect(response).to have_http_status(:ok)
    end

    it "ends when the admin signs out" do
      delete destroy_user_session_path

      expect(ImpersonationEvent.last.reload).not_to be_active
    end
  end

  describe "session tampering" do
    it "ignores an impersonation session set by a non-admin" do
      sign_in tenant.member

      # Simulated by starting a legitimate session, then dropping the admin
      # flag — every request re-checks authority, it is not trusted once.
      sign_out tenant.member
      sign_in platform_admin
      start_impersonating

      platform_admin.update!(admin: false)
      get dashboard_path

      expect(response.body).not_to include("Impersonating")
    end
  end
end
