# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Invitations" do
  let(:tenant) { create_tenant }

  describe "sending" do
    it "lets an admin invite someone and emails them" do
      admin = create(:user)
      create(:membership, :admin, user: admin, team: tenant.team)
      sign_in admin

      expect {
        post team_invitations_path(tenant.team),
             params: { team_invitation: { email: "new@example.com", role: "member" } }
      }.to change { tenant.team.invitations.count }.by(1)

      expect(ActionMailer::Base.deliveries.size + enqueued_jobs.size).to be_positive
    end

    it "does not let a member invite" do
      sign_in tenant.member

      post team_invitations_path(tenant.team),
           params: { team_invitation: { email: "nope@example.com", role: "member" } }

      expect(tenant.team.invitations.count).to eq(0)
    end

    it "does not let an admin invite someone as an owner" do
      admin = create(:user)
      create(:membership, :admin, user: admin, team: tenant.team)
      sign_in admin

      acting_as(admin, team: tenant.team) do
        expect(TeamInvitationPolicy.new(admin, TeamInvitation).invitable_roles)
          .not_to include("owner")
      end
    end

    it "refuses to invite someone who is already a member" do
      sign_in tenant.owner

      post team_invitations_path(tenant.team),
           params: { team_invitation: { email: tenant.member.email, role: "member" } }

      expect(tenant.team.invitations.count).to eq(0)
      expect(flash[:alert]).to match(/already a member/i)
    end

    it "reuses an expired invitation rather than colliding with it" do
      create(:team_invitation, :expired, team: tenant.team, email: "again@example.com")
      sign_in tenant.owner

      expect {
        post team_invitations_path(tenant.team),
             params: { team_invitation: { email: "again@example.com", role: "member" } }
      }.not_to raise_error

      expect(tenant.team.invitations.pending.count).to eq(1)
    end

    it "cannot invite into a team the user does not belong to" do
      other = create_tenant
      sign_in tenant.owner

      post team_invitations_path(other.team),
           params: { team_invitation: { email: "x@example.com", role: "member" } }

      expect(response).to have_http_status(:not_found)
      expect(other.team.invitations.count).to eq(0)
    end
  end

  describe "accepting" do
    let(:invitation) { create(:team_invitation, team: tenant.team, email: "joiner@example.com", role: "admin") }

    it "sends a signed-out visitor to sign in first" do
      get invitation_path(invitation.token)

      expect(response).to redirect_to(new_user_session_path)
    end

    it "creates the membership with the invited role" do
      joiner = create(:user, email: "joiner@example.com")
      sign_in joiner

      post accept_invitation_path(invitation.token)

      membership = joiner.memberships.find_by(team: tenant.team)
      expect(membership).to be_present
      expect(membership).to be_admin
      expect(invitation.reload).to be_accepted
    end

    it "refuses when signed in as a different address" do
      intruder = create(:user, email: "someone-else@example.com")
      sign_in intruder

      post accept_invitation_path(invitation.token)

      expect(intruder.memberships.where(team: tenant.team)).to be_empty
    end

    it "refuses an expired invitation" do
      expired = create(:team_invitation, :expired, team: tenant.team, email: "late@example.com")
      joiner = create(:user, email: "late@example.com")
      sign_in joiner

      post accept_invitation_path(expired.token)

      expect(joiner.memberships.where(team: tenant.team)).to be_empty
    end

    it "is harmless when accepted twice" do
      joiner = create(:user, email: "joiner@example.com")
      sign_in joiner

      post accept_invitation_path(invitation.token)
      post accept_invitation_path(invitation.token)

      expect(joiner.memberships.where(team: tenant.team).count).to eq(1)
    end

    it "does not resolve an unknown token" do
      sign_in create(:user)

      get invitation_path("not-a-real-token")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "revoking" do
    it "lets an admin revoke a pending invitation" do
      invitation = create(:team_invitation, team: tenant.team)
      sign_in tenant.owner

      delete team_invitation_path(tenant.team, invitation)

      expect(TeamInvitation.exists?(invitation.id)).to be(false)
    end

    it "cannot revoke another team's invitation" do
      other = create_tenant
      invitation = create(:team_invitation, team: other.team)
      sign_in tenant.owner

      delete team_invitation_path(tenant.team, invitation)

      expect(response).to have_http_status(:not_found)
      expect(TeamInvitation.exists?(invitation.id)).to be(true)
    end
  end

  describe "changing roles and removing members" do
    it "lets an owner promote a member" do
      sign_in tenant.owner
      membership = tenant.member.memberships.first

      patch team_member_path(tenant.team, membership), params: { membership: { role: "admin" } }

      expect(membership.reload).to be_admin
    end

    it "lets an owner remove a member" do
      sign_in tenant.owner
      membership = tenant.member.memberships.first

      delete team_member_path(tenant.team, membership)

      expect(Membership.exists?(membership.id)).to be(false)
    end

    it "cannot touch a membership in another team" do
      other = create_tenant
      sign_in tenant.owner

      delete team_member_path(tenant.team, other.member.memberships.first)

      expect(response).to have_http_status(:not_found)
    end
  end
end
