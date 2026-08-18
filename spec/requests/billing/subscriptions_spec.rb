# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Billing" do
  let(:tenant) { create_tenant }

  before { stub_stripe_credentials }

  describe "access" do
    it "lets an owner see billing" do
      sign_in tenant.owner
      get billing_subscription_path

      expect(response).to have_http_status(:ok)
    end

    it "lets an admin see billing" do
      admin = create(:user)
      create(:membership, :admin, user: admin, team: tenant.team)
      sign_in admin

      get billing_subscription_path
      expect(response).to have_http_status(:ok)
    end

    it "does not let a plain member see billing" do
      sign_in tenant.member
      get billing_subscription_path

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to be_present
    end

    it "shows the active team's subscription only" do
      create(:subscription, team: tenant.team, plan_key: "starter")
      other = create_tenant
      create(:subscription, team: other.team, plan_key: "pro",
                            stripe_subscription_id: "sub_other")

      sign_in tenant.owner
      get billing_subscription_path

      expect(response.body).to include("Starter")
      expect(response.body).not_to include("sub_other")
    end
  end

  describe "checkout" do
    it "does not let an admin start a subscription — owners only" do
      admin = create(:user)
      create(:membership, :admin, user: admin, team: tenant.team)
      sign_in admin

      post checkout_billing_subscription_path(plan: "starter")

      expect(response).to have_http_status(:found)
      expect(flash[:alert]).to be_present
    end

    it "reports a clear error when no Stripe price is configured" do
      allow(Rails.application.credentials).to receive(:dig).and_call_original
      allow(Rails.application.credentials)
        .to receive(:dig).with(:stripe, :prices, :starter_monthly).and_return(nil)

      sign_in tenant.owner
      post checkout_billing_subscription_path(plan: "starter")

      expect(flash[:alert]).to include('No Stripe price is configured')
    end
  end

  describe "the post-checkout landing page" do
    it "does not claim success just because Stripe redirected here" do
      sign_in tenant.owner
      get billing_checkout_success_path

      # No subscription exists yet — the webhook has not arrived. The page must
      # say it is waiting, not that the team is subscribed.
      expect(response.body).to include("Confirming your subscription")
      expect(response.body).not_to include("is active for")
      expect(tenant.team.reload.subscription).to be_nil
    end

    it "confirms only once local state says the subscription is active" do
      create(:subscription, team: tenant.team, status: "active", quantity: 2)

      sign_in tenant.owner
      get billing_checkout_success_path

      expect(response.body).to include("is active for")
    end
  end
end
