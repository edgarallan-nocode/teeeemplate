# frozen_string_literal: true

require "rails_helper"

# == Schema Information
#
# Table name: teams
#
#  id                 :bigint           not null, primary key
#  name               :string           not null
#  slug               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  stripe_customer_id :string
#
# Indexes
#
#  index_teams_on_slug                (slug) UNIQUE
#  index_teams_on_stripe_customer_id  (stripe_customer_id) UNIQUE
#
RSpec.describe Team do
  describe "validations" do
    subject { build(:team) }

    it { is_expected.to validate_presence_of(:name) }

    it "rejects a duplicate slug" do
      create(:team, slug: "acme")
      duplicate = build(:team, slug: "acme")
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:slug]).to be_present
    end
  end

  describe "slug generation" do
    it "derives a slug from the name" do
      expect(create(:team, name: "Acme Widgets").slug).to eq("acme-widgets")
    end

    it "disambiguates a slug that is already taken" do
      create(:team, name: "Acme Widgets")
      expect(create(:team, name: "Acme Widgets").slug).to eq("acme-widgets-2")
    end

    it "keeps an explicitly provided slug" do
      expect(create(:team, name: "Acme Widgets", slug: "acme").slug).to eq("acme")
    end

    it "rejects a slug with invalid characters" do
      team = build(:team, slug: "Not A Slug")
      expect(team).not_to be_valid
      expect(team.errors[:slug]).to be_present
    end
  end

  describe "#subscription_active?" do
    it "is false without a subscription" do
      expect(create(:team).subscription_active?).to be(false)
    end

    it "is true for an active subscription" do
      team = create(:team)
      create(:subscription, team: team, status: "active")
      expect(team.reload.subscription_active?).to be(true)
    end

    it "is true while past due, so a failed card does not lock the team out instantly" do
      team = create(:team)
      create(:subscription, team: team, status: "past_due")
      expect(team.reload.subscription_active?).to be(true)
    end

    it "is false once canceled" do
      team = create(:team)
      create(:subscription, team: team, status: "canceled")
      expect(team.reload.subscription_active?).to be(false)
    end
  end

  describe "#seat_count" do
    it "counts every membership" do
      team = create(:team)
      create_list(:membership, 3, team: team)
      expect(team.seat_count).to eq(3)
    end
  end
end
