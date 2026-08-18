# frozen_string_literal: true

Stripe.api_key = Rails.application.credentials.dig(:stripe, :secret_key)
Stripe.api_version = "2025-03-31.basil"
Stripe.max_network_retries = 2

# Every mutating Stripe call in this application passes an idempotency key so a
# retried background job cannot create a duplicate customer or subscription.
# See app/services/billing/.
