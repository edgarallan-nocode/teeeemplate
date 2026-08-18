# frozen_string_literal: true

require "rails_helper"

# Policies are tested per role, for both the permitted and the forbidden case.
# A policy spec that only asserts the happy path proves nothing.
RSpec.describe "Policies" do
  let(:team) { create(:team) }
  let(:owner)  { create(:user).tap { |u| create(:membership, :owner,  user: u, team: team) } }
  let(:admin)  { create(:user).tap { |u| create(:membership, :admin,  user: u, team: team) } }
  let(:member) { create(:user).tap { |u| create(:membership, :member, user: u, team: team) } }
  let(:outsider) { create(:user) }

  # Evaluates a policy question with Current set the way a request would set it.
  def as(user, record, question, policy_class: nil)
    acting_as(user, team: team) do
      klass = policy_class || Pundit::PolicyFinder.new(record).policy
      klass.new(user, record).public_send(question)
    end
  end

  describe TeamPolicy do
    it "lets any signed-in user create a team" do
      expect(as(member, Team, :create?)).to be(true)
    end

    it "restricts team settings to admins and above" do
      expect(as(owner,  team, :update?)).to be(true)
      expect(as(admin,  team, :update?)).to be(true)
      expect(as(member, team, :update?)).to be(false)
    end

    it "restricts deleting a team to owners" do
      expect(as(owner,  team, :destroy?)).to be(true)
      expect(as(admin,  team, :destroy?)).to be(false)
      expect(as(member, team, :destroy?)).to be(false)
    end

    it "refuses to delete a team while impersonating, even as an owner" do
      acting_as(owner, team: team) do
        Current.true_user = create(:user, :admin)
        expect(described_class.new(owner, team).destroy?).to be(false)
      end
    end

    it "lets a member leave but not the last owner" do
      expect(as(member, team, :leave?)).to be(true)
      expect(as(owner,  team, :leave?)).to be(false)
    end

    it "refuses everything to a non-member" do
      expect(as(outsider, team, :show?)).to be(false)
      expect(as(outsider, team, :update?)).to be(false)
    end
  end

  describe MembershipPolicy do
    let(:member_membership) { member.memberships.first }
    let(:owner_membership)  { owner.memberships.first }

    it "lets an admin change a member's role" do
      expect(as(admin, member_membership, :update?)).to be(true)
    end

    it "does not let an admin change an owner's role" do
      other_owner = create(:membership, :owner, team: team) # not the last owner
      expect(as(admin, other_owner, :update?)).to be(false)
    end

    it "lets an owner change another owner's role" do
      other_owner = create(:membership, :owner, team: team)
      expect(as(owner, other_owner, :update?)).to be(true)
    end

    it "never allows changing the last owner's role" do
      expect(as(owner, owner_membership, :update?)).to be(false)
    end

    it "does not let anyone change their own role" do
      expect(as(admin, admin.memberships.first, :update?)).to be(false)
    end

    it "does not let a member change roles at all" do
      expect(as(member, member_membership, :update?)).to be(false)
    end

    it "offers owner as an assignable role only to owners" do
      acting_as(owner, team: team) do
        expect(described_class.new(owner, member_membership).assignable_roles).to include("owner")
      end
      acting_as(admin, team: team) do
        expect(described_class.new(admin, member_membership).assignable_roles).not_to include("owner")
      end
    end
  end

  describe SubscriptionPolicy do
    let(:subscription) { create(:subscription, team: team) }

    it "lets admins and owners view billing, but not members" do
      expect(as(owner,  subscription, :show?)).to be(true)
      expect(as(admin,  subscription, :show?)).to be(true)
      expect(as(member, subscription, :show?)).to be(false)
    end

    it "restricts starting and managing a subscription to owners" do
      expect(as(owner,  subscription, :checkout?)).to be(true)
      expect(as(admin,  subscription, :checkout?)).to be(false)
      expect(as(member, subscription, :portal?)).to be(false)
    end

    it "blocks all money movement while impersonating, even for an owner" do
      acting_as(owner, team: team) do
        Current.true_user = create(:user, :admin)

        policy = described_class.new(owner, subscription)
        expect(policy.checkout?).to be(false)
        expect(policy.portal?).to be(false)
        expect(policy.show?).to be(true) # looking is fine; spending is not
      end
    end
  end

  describe ProjectPolicy do
    let(:project) { create(:project, team: team) }

    it "lets any member create and edit" do
      expect(as(member, project, :create?)).to be(true)
      expect(as(member, project, :update?)).to be(true)
    end

    it "restricts destroying to admins and above" do
      expect(as(member, project, :destroy?)).to be(false)
      expect(as(admin,  project, :destroy?)).to be(true)
    end

    it "refuses everything to a non-member" do
      expect(as(outsider, project, :show?)).to be(false)
      expect(as(outsider, project, :create?)).to be(false)
    end
  end

  describe Admin::UserPolicy do
    let(:platform_admin) { create(:user, :admin) }

    it "is closed to ordinary users" do
      expect(described_class.new(member, outsider).index?).to be(false)
    end

    it "is open to platform admins" do
      expect(described_class.new(platform_admin, outsider).index?).to be(true)
    end

    it "refuses to impersonate another admin" do
      other_admin = create(:user, :admin)
      expect(described_class.new(platform_admin, other_admin).impersonate?).to be(false)
    end

    it "refuses to impersonate yourself" do
      expect(described_class.new(platform_admin, platform_admin).impersonate?).to be(false)
    end

    it "allows impersonating an ordinary user" do
      expect(described_class.new(platform_admin, member).impersonate?).to be(true)
    end

    it "does not let a non-admin impersonate anyone" do
      expect(described_class.new(member, outsider).impersonate?).to be(false)
    end
  end
end
