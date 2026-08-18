# frozen_string_literal: true

# Stripe test support.
#
# Webhook specs sign their payloads with Stripe's own signature algorithm rather
# than stubbing verification away. That means the specs exercise the real
# `Stripe::Webhook.construct_event` path — if signature checking were removed
# from the controller, the specs would still pass against a stub, but they fail
# against this.
module StripeHelpers
  WEBHOOK_SECRET = "whsec_test_secret_for_specs"

  def stripe_webhook_secret = WEBHOOK_SECRET

  # A genuinely signed Stripe-Signature header for the given payload.
  def stripe_signature_header(payload, secret: WEBHOOK_SECRET, timestamp: Time.current)
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, secret)
    Stripe::Webhook::Signature.generate_header(timestamp, signature)
  end

  def post_stripe_webhook(event, secret: WEBHOOK_SECRET, timestamp: Time.current, headers: {})
    payload = event.is_a?(String) ? event : JSON.generate(event)

    post billing_webhooks_path,
         params: payload,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "HTTP_STRIPE_SIGNATURE" => stripe_signature_header(payload, secret:, timestamp:)
         }.merge(headers)
  end

  def stripe_event(type:, object:, id: nil)
    {
      id: id || "evt_#{SecureRandom.hex(12)}",
      object: "event",
      api_version: Stripe.api_version,
      created: Time.current.to_i,
      type: type,
      livemode: false,
      data: { object: object }
    }
  end

  def stripe_subscription_object(**overrides)
    {
      id: "sub_#{SecureRandom.hex(8)}",
      object: "subscription",
      customer: "cus_#{SecureRandom.hex(8)}",
      status: "active",
      quantity: 2,
      cancel_at_period_end: false,
      canceled_at: nil,
      trial_end: nil,
      items: {
        object: "list",
        data: [ {
          id: "si_#{SecureRandom.hex(8)}",
          object: "subscription_item",
          quantity: 2,
          current_period_end: 30.days.from_now.to_i,
          price: { id: "price_starter_monthly", object: "price" }
        } ]
      }
    }.deep_merge(overrides)
  end

  def stripe_checkout_session_object(**overrides)
    {
      id: "cs_#{SecureRandom.hex(8)}",
      object: "checkout.session",
      customer: "cus_#{SecureRandom.hex(8)}",
      subscription: "sub_#{SecureRandom.hex(8)}",
      mode: "subscription",
      status: "complete",
      payment_status: "paid",
      client_reference_id: nil,
      metadata: {}
    }.deep_merge(overrides)
  end

  # Points the application at the spec webhook secret and fake price ids.
  def stub_stripe_credentials
    allow(Rails.application.credentials).to receive(:dig).and_call_original
    allow(Rails.application.credentials)
      .to receive(:dig).with(:stripe, :webhook_secret).and_return(WEBHOOK_SECRET)
    allow(Rails.application.credentials)
      .to receive(:dig).with(:stripe, :prices, :starter_monthly).and_return("price_starter_monthly")
    allow(Rails.application.credentials)
      .to receive(:dig).with(:stripe, :prices, :pro_monthly).and_return("price_pro_monthly")
  end
end
