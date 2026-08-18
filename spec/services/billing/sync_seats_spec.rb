# frozen_string_literal: true

require "rails_helper"

RSpec.describe Billing::SyncSeats do
  let(:team) { create(:team) }

  context "with no subscription" do
    it "does nothing" do
      create(:membership, :owner, team: team)

      expect(Stripe::SubscriptionItem).not_to receive(:update)
      expect(described_class.call(team: team).value).to eq(:no_subscription)
    end
  end

  context "with an active subscription" do
    let!(:owner) { create(:membership, :owner, team: team) }
    let!(:subscription) do
      create(:subscription, team: team, status: "active", quantity: 1,
                            stripe_subscription_item_id: "si_test")
    end

    it "pushes the new seat count to Stripe when a member is added" do
      create(:membership, team: team)

      expect(Stripe::SubscriptionItem).to receive(:update)
        .with("si_test", hash_including(quantity: 2), any_args)

      described_class.call(team: team.reload)
      expect(subscription.reload.quantity).to eq(2)
    end

    it "lowers the count when a member is removed" do
      extra = create(:membership, team: team)
      subscription.update!(quantity: 2)
      allow(Stripe::SubscriptionItem).to receive(:update)

      extra.destroy!
      described_class.call(team: team.reload)

      expect(subscription.reload.quantity).to eq(1)
    end

    it "does nothing when the count already matches" do
      expect(Stripe::SubscriptionItem).not_to receive(:update)

      expect(described_class.call(team: team).value).to eq(:unchanged)
    end

    it "is idempotent — running it twice makes one Stripe call" do
      create(:membership, team: team)
      allow(Stripe::SubscriptionItem).to receive(:update)

      described_class.call(team: team.reload)
      described_class.call(team: team.reload)

      expect(Stripe::SubscriptionItem).to have_received(:update).once
    end

    it "asks Stripe to prorate the change" do
      create(:membership, team: team)

      expect(Stripe::SubscriptionItem).to receive(:update)
        .with(anything, hash_including(proration_behavior: "create_prorations"), any_args)

      described_class.call(team: team.reload)
    end

    it "sends an idempotency key so a retried job cannot double-charge" do
      create(:membership, team: team)

      expect(Stripe::SubscriptionItem).to receive(:update)
        .with(anything, anything, hash_including(:idempotency_key))

      described_class.call(team: team.reload)
    end
  end

  context "with a subscription that is not billable" do
    it "skips a canceled subscription" do
      create(:membership, :owner, team: team)
      create(:subscription, team: team, status: "canceled", quantity: 5)

      expect(Stripe::SubscriptionItem).not_to receive(:update)
      expect(described_class.call(team: team).value).to eq(:not_billable)
    end
  end

  describe "the job that drives it" do
    it "runs from a membership change and recomputes from the database" do
      create(:subscription, team: team, status: "active", quantity: 0,
                            stripe_subscription_item_id: "si_job")
      allow(Stripe::SubscriptionItem).to receive(:update)

      create(:membership, :owner, team: team)
      perform_enqueued_jobs

      expect(team.subscription.reload.quantity).to eq(1)
    end

    it "does nothing when the team is gone by the time it runs" do
      expect { Billing::SyncSeatsJob.perform_now(-1) }.not_to raise_error
    end
  end
end
