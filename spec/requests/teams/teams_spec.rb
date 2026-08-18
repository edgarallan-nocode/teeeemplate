# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teams" do
  describe "creating" do
    let(:user) { create(:user) }

    before { sign_in user }

    it "creates the team, makes the creator its owner, and switches to it" do
      post teams_path, params: { team: { name: "Acme Widgets" } }

      team = Team.find_by(name: "Acme Widgets")
      expect(team).to be_present
      expect(user.memberships.find_by(team: team)).to be_owner
      expect(user.reload.last_team_id).to eq(team.id)
      expect(response).to redirect_to(dashboard_path)
    end

    it "queues Stripe customer creation rather than doing it inline" do
      expect { post teams_path, params: { team: { name: "Deferred" } } }
        .to have_enqueued_job(Billing::CreateCustomerJob)
    end

    it "re-renders with errors for a blank name" do
      post teams_path, params: { team: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Team.count).to eq(0)
    end
  end

  describe "switching" do
    it "changes the active team and remembers it for the next session" do
      user = create(:user)
      a = create(:team, name: "Alpha")
      b = create(:team, name: "Beta")
      create(:membership, :owner, user: user, team: a)
      create(:membership, :owner, user: user, team: b)

      sign_in user
      post team_switch_path(b)

      expect(user.reload.last_team_id).to eq(b.id)

      get dashboard_path
      expect(response.body).to include("Beta")
      expect(response.body).not_to include("Alpha</h1>")
    end

    it "refuses to switch to a team the user does not belong to" do
      user = create(:user, :with_team)
      stranger_team = create(:team, name: "Not Yours")

      sign_in user
      post team_switch_path(stranger_team)

      expect(response).to have_http_status(:not_found)
      expect(user.reload.last_team_id).not_to eq(stranger_team.id)
    end
  end

  describe "settings" do
    let(:tenant) { create_tenant }

    it "lets an owner rename the team" do
      sign_in tenant.owner
      patch team_path(tenant.team), params: { team: { name: "Renamed Co" } }

      expect(tenant.team.reload.name).to eq("Renamed Co")
    end

    it "does not let a member rename the team" do
      sign_in tenant.member
      patch team_path(tenant.team), params: { team: { name: "Hijacked" } }

      expect(tenant.team.reload.name).not_to eq("Hijacked")
    end

    it "is not reachable for a team the user does not belong to" do
      other = create_tenant

      sign_in tenant.owner
      get edit_team_path(other.team)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "leaving" do
    let(:tenant) { create_tenant }

    it "lets a member leave" do
      sign_in tenant.member
      post team_leave_path(tenant.team)

      expect(tenant.team.reload.users).not_to include(tenant.member)
    end

    it "refuses to let the last owner leave" do
      sign_in tenant.owner
      post team_leave_path(tenant.team)

      expect(tenant.team.reload.users).to include(tenant.owner)
      expect(flash[:alert]).to match(/only owner/i)
    end
  end

  describe "deleting" do
    let(:tenant) { create_tenant }

    it "lets an owner delete the team and everything in it" do
      create(:team_invitation, team: tenant.team)

      sign_in tenant.owner
      delete team_path(tenant.team)

      expect(Team.exists?(tenant.team.id)).to be(false)
      expect(Membership.where(team_id: tenant.team.id)).to be_empty
      expect(TeamInvitation.where(team_id: tenant.team.id)).to be_empty
    end

    it "does not let a member delete the team" do
      sign_in tenant.member
      delete team_path(tenant.team)

      expect(Team.exists?(tenant.team.id)).to be(true)
    end
  end
end
