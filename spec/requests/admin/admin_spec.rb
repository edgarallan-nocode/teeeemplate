# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Platform admin" do
  let(:platform_admin) { create(:user, :admin) }
  let(:tenant) { create_tenant }

  describe "access" do
    it "refuses an ordinary user" do
      sign_in tenant.owner
      get admin_root_path

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to be_present
    end

    it "refuses a signed-out visitor" do
      get admin_root_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "admits a platform admin" do
      sign_in platform_admin
      get admin_root_path

      expect(response).to have_http_status(:ok)
    end

    it "grants no team powers — being a platform admin is not a team role" do
      # The admin has their own team, so the ordinary app works for them. It
      # still treats another team's record as non-existent: platform admin is
      # staff access to this install, not membership of every team.
      admin_with_team = create(:user, :admin, :with_team)
      project = create(:project, team: tenant.team)

      sign_in admin_with_team
      get project_path(project)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "browsing" do
    before { sign_in platform_admin }

    it "lists users and searches them" do
      create(:user, email: "findme@example.com", first_name: "Find", last_name: "Me")

      get admin_users_path, params: { q: "findme" }

      expect(response.body).to include("findme@example.com")
    end

    it "lists teams and searches them" do
      create(:team, name: "Searchable Co")

      get admin_teams_path, params: { q: "Searchable" }

      expect(response.body).to include("Searchable Co")
    end

    it "shows a team with its members and subscription state" do
      create(:subscription, team: tenant.team, status: "past_due")

      get admin_team_path(tenant.team)

      expect(response.body).to include(tenant.team.name)
      expect(response.body).to include(tenant.owner.email)
      expect(response.body).to include("Past due")
    end

    it "filters subscriptions by status" do
      create(:subscription, team: tenant.team, status: "canceled")
      other = create_tenant
      create(:subscription, team: other.team, status: "active",
                            stripe_subscription_id: "sub_active_one")

      get admin_subscriptions_path, params: { status: "canceled" }

      expect(response.body).to include(tenant.team.name)
      expect(response.body).not_to include("sub_active_one")
    end
  end
end
