# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Stripe webhooks" do
  before { stub_stripe_credentials }

  let(:team) { create(:team, stripe_customer_id: "cus_test_123") }
  let(:event) do
    stripe_event(
      type: "customer.subscription.updated",
      object: stripe_subscription_object(customer: team.stripe_customer_id)
    )
  end

  describe "signature verification" do
    it "accepts a correctly signed payload" do
      post_stripe_webhook(event)

      expect(response).to have_http_status(:ok)
      expect(StripeEvent.count).to eq(1)
    end

    it "rejects a payload with no signature header at all" do
      post billing_webhooks_path,
           params: JSON.generate(event),
           headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:bad_request)
      expect(StripeEvent.count).to eq(0)
    end

    it "rejects a payload signed with the wrong secret" do
      post_stripe_webhook(event, secret: "whsec_a_different_secret")

      expect(response).to have_http_status(:bad_request)
      expect(StripeEvent.count).to eq(0)
    end

    it "rejects a payload that was tampered with after signing" do
      payload = JSON.generate(event)
      header = stripe_signature_header(payload)
      tampered = payload.sub("customer.subscription.updated", "customer.subscription.deleted")

      post billing_webhooks_path,
           params: tampered,
           headers: {
             "CONTENT_TYPE" => "application/json",
             "HTTP_STRIPE_SIGNATURE" => header
           }

      expect(response).to have_http_status(:bad_request)
      expect(StripeEvent.count).to eq(0)
    end

    it "rejects a validly signed payload that is outside the tolerance window" do
      # Replay protection: an old signature is still refused.
      post_stripe_webhook(event, timestamp: 1.hour.ago)

      expect(response).to have_http_status(:bad_request)
      expect(StripeEvent.count).to eq(0)
    end

    it "rejects a body that is not JSON" do
      post_stripe_webhook("this is not json{")

      expect(response).to have_http_status(:bad_request)
    end

    it "does not enqueue any work for a rejected request" do
      expect { post_stripe_webhook(event, secret: "whsec_wrong") }
        .not_to have_enqueued_job(Billing::ProcessStripeEventJob)
    end
  end

  describe "idempotency" do
    it "records the event once and enqueues processing once" do
      expect { post_stripe_webhook(event) }
        .to have_enqueued_job(Billing::ProcessStripeEventJob).exactly(:once)

      expect(StripeEvent.count).to eq(1)
    end

    it "returns 200 for a redelivery without recording it twice" do
      post_stripe_webhook(event)
      expect(StripeEvent.count).to eq(1)

      # Stripe retries on any non-2xx and guarantees only at-least-once
      # delivery, so a repeated event id is normal rather than an error.
      expect { post_stripe_webhook(event) }.not_to change(StripeEvent, :count)
      expect(response).to have_http_status(:ok)
    end

    it "does not enqueue processing a second time for a redelivery" do
      post_stripe_webhook(event)

      expect { post_stripe_webhook(event) }
        .not_to have_enqueued_job(Billing::ProcessStripeEventJob)
    end

    it "applies the state change only once across a redelivery" do
      perform_enqueued_jobs do
        post_stripe_webhook(event)
        post_stripe_webhook(event)
      end

      expect(Subscription.where(team: team).count).to eq(1)
      expect(StripeEvent.count).to eq(1)
    end

    it "treats two genuinely different events as different" do
      post_stripe_webhook(event)
      post_stripe_webhook(
        stripe_event(
          type: "customer.subscription.updated",
          object: stripe_subscription_object(customer: team.stripe_customer_id)
        )
      )

      expect(StripeEvent.count).to eq(2)
    end
  end

  describe "the endpoint's shape" do
    it "requires no authentication and no CSRF token" do
      post_stripe_webhook(event)

      expect(response).to have_http_status(:ok)
    end

    it "records unhandled event types without acting on them" do
      perform_enqueued_jobs do
        post_stripe_webhook(
          stripe_event(type: "invoice.created", object: { id: "in_123", object: "invoice" })
        )
      end

      record = StripeEvent.sole
      expect(record.event_type).to eq("invoice.created")
      expect(record).to be_processed
      expect(Subscription.count).to eq(0)
    end
  end
end
