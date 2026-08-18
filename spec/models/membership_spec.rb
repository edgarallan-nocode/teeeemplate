# frozen_string_literal: true

require "rails_helper"

# == Schema Information
#
# Table name: memberships
#
#  id         :bigint           not null, primary key
#  role       :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_memberships_on_team_id              (team_id)
#  index_memberships_on_team_id_and_role     (team_id,role)
#  index_memberships_on_user_id              (user_id)
#  index_memberships_on_user_id_and_team_id  (user_id,team_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#
RSpec.describe Membership do
  describe "roles" do
    it "orders roles so that comparisons work" do
      expect(described_class.roles).to eq("member" => 0, "admin" => 1, "owner" => 2)
    end

    it "answers at_least? by rank rather than by name" do
      owner  = build(:membership, role: :owner)
      admin  = build(:membership, role: :admin)
      member = build(:membership, role: :member)

      expect(owner).to be_at_least(:admin)
      expect(admin).to be_at_least(:admin)
      expect(member).not_to be_at_least(:admin)
      expect(member).to be_at_least(:member)
    end
  end

  describe "uniqueness" do
    it "allows a user only one membership per team" do
      team = create(:team)
      user = create(:user)
      create(:membership, user: user, team: team)

      duplicate = build(:membership, user: user, team: team)
      expect(duplicate).not_to be_valid
    end

    it "allows the same user in different teams" do
      user = create(:user)
      create(:membership, user: user, team: create(:team))
      expect(build(:membership, user: user, team: create(:team))).to be_valid
    end
  end

  describe "the last-owner invariant" do
    let(:team) { create(:team) }
    let!(:owner) { create(:membership, :owner, team: team) }

    it "refuses to demote the only owner" do
      owner.role = :member
      expect(owner).not_to be_valid
      expect(owner.errors[:role].first).to include('at least one owner')
    end

    it "refuses to destroy the only owner" do
      expect(owner.destroy).to be(false)
      expect(team.reload.memberships).to include(owner)
    end

    it "allows demoting an owner when another owner remains" do
      create(:membership, :owner, team: team)
      owner.role = :member
      expect(owner).to be_valid
    end

    it "allows destroying an owner when another owner remains" do
      create(:membership, :owner, team: team)
      expect(owner.destroy).to be_truthy
    end

    it "allows a non-owner to be destroyed freely" do
      member = create(:membership, :member, team: team)
      expect(member.destroy).to be_truthy
    end

    it "reports #last_owner? correctly" do
      expect(owner).to be_last_owner
      create(:membership, :owner, team: team)
      expect(owner.reload).not_to be_last_owner
    end
  end

  describe "seat syncing" do
    it "enqueues a seat sync when a member joins" do
      team = create(:team)
      expect { create(:membership, team: team) }
        .to have_enqueued_job(Billing::SyncSeatsJob).with(team.id)
    end

    it "enqueues a seat sync when a member leaves" do
      team = create(:team)
      create(:membership, :owner, team: team)
      membership = create(:membership, team: team)

      expect { membership.destroy }
        .to have_enqueued_job(Billing::SyncSeatsJob).with(team.id)
    end
  end
end
