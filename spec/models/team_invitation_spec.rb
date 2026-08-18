# frozen_string_literal: true

require "rails_helper"

# == Schema Information
#
# Table name: team_invitations
#
#  id             :bigint           not null, primary key
#  accepted_at    :datetime
#  email          :string           not null
#  expires_at     :datetime         not null
#  role           :integer          default(0), not null
#  token          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  accepted_by_id :bigint
#  invited_by_id  :bigint           not null
#  team_id        :bigint           not null
#
# Indexes
#
#  index_team_invitations_on_accepted_by_id          (accepted_by_id)
#  index_team_invitations_on_invited_by_id           (invited_by_id)
#  index_team_invitations_on_team_id                 (team_id)
#  index_team_invitations_on_token                   (token) UNIQUE
#  index_team_invitations_pending_on_team_and_email  (team_id,email) UNIQUE WHERE (accepted_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (accepted_by_id => users.id)
#  fk_rails_...  (invited_by_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#
RSpec.describe TeamInvitation do
  it "normalizes the email" do
    invitation = create(:team_invitation, email: "  Person@Example.COM ")
    expect(invitation.email).to eq("person@example.com")
  end

  it "generates a token and an expiry" do
    invitation = create(:team_invitation)
    expect(invitation.token).to be_present
    expect(invitation.expires_at).to be_within(1.minute).of(described_class::EXPIRY.from_now)
  end

  it "rejects an invitation to someone already on the team" do
    team = create(:team)
    member = create(:user, email: "existing@example.com")
    create(:membership, user: member, team: team)

    invitation = build(:team_invitation, team: team, email: "existing@example.com")
    expect(invitation).not_to be_valid
    expect(invitation.errors[:email].first).to include('already a member')
  end

  it "allows one pending invitation per email per team" do
    team = create(:team)
    create(:team_invitation, team: team, email: "dup@example.com")

    expect { create(:team_invitation, team: team, email: "dup@example.com") }
      .to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows a fresh invitation once the previous one was accepted" do
    team = create(:team)
    create(:team_invitation, :accepted, team: team, email: "again@example.com")

    expect { create(:team_invitation, team: team, email: "again@example.com") }
      .not_to raise_error
  end

  it "allows the same email in different teams" do
    create(:team_invitation, team: create(:team), email: "shared@example.com")
    expect(build(:team_invitation, team: create(:team), email: "shared@example.com")).to be_valid
  end

  describe "state" do
    it "is pending when neither accepted nor expired" do
      expect(create(:team_invitation)).to be_pending
    end

    it "is expired past its expiry" do
      invitation = create(:team_invitation, :expired)
      expect(invitation).to be_expired
      expect(invitation).not_to be_pending
    end

    it "is not pending once accepted" do
      expect(create(:team_invitation, :accepted)).not_to be_pending
    end

    it "excludes expired and accepted invitations from .pending" do
      team = create(:team)
      live = create(:team_invitation, team: team)
      create(:team_invitation, :expired, team: team)
      create(:team_invitation, :accepted, team: team)

      expect(team.invitations.pending).to contain_exactly(live)
    end
  end
end
