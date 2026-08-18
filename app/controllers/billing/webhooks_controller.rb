# frozen_string_literal: true

module Billing
  # Stripe's webhook endpoint.
  #
  # Deliberately the thinnest controller in the application. It does five things
  # in a fixed order and nothing else:
  #
  #   1. verify the signature       — an unsigned or tampered request gets 400
  #   2. record the event id        — the unique index rejects a redelivery
  #   3. enqueue the real work      — nothing slow happens in the request
  #   4. return 200                 — quickly, so Stripe does not retry
  #   5. never touch Current        — there is no user and no team here
  #
  # Any work that could be slow, could fail, or could call back out to Stripe
  # belongs in Billing::ProcessStripeEvent, not here.
  class WebhooksController < ActionController::Base
    protect_from_forgery with: :null_session

    def create
      event = verified_event
      return head :bad_request if event.nil?

      record = record_event(event)

      # Nil means we have seen this event id before. Stripe redelivers on any
      # non-2xx, and at-least-once delivery is normal, so a duplicate is an
      # expected condition rather than an error.
      return head :ok if record.nil?

      Billing::ProcessStripeEventJob.perform_later(record.id)

      head :ok
    end

    private

    def verified_event
      Stripe::Webhook.construct_event(
        request.body.read,
        request.headers["Stripe-Signature"],
        webhook_secret
      )
    rescue JSON::ParserError, Stripe::SignatureVerificationError => e
      # Do not report to Sentry: a public endpoint receives junk, and a failed
      # signature check is the endpoint working correctly.
      Rails.logger.warn("[stripe] rejected webhook: #{e.class}: #{e.message}")
      nil
    end

    # Returns nil when this event has already been recorded.
    #
    # Both rescues are needed and neither is redundant:
    #
    #   RecordInvalid   the model's uniqueness validation caught it, which is
    #                   what happens for an ordinary redelivery
    #   RecordNotUnique the database index caught it, which is what happens
    #                   when two deliveries race past the validation at once
    #
    # The index is the guarantee; the validation is only the fast path. Other
    # validation failures are deliberately not swallowed — they are bugs and
    # should surface as a 500 so Stripe retries and Sentry records them.
    def record_event(event)
      StripeEvent.create!(
        stripe_event_id: event.id,
        event_type: event.type,
        payload: event.to_hash.deep_stringify_keys
      )
    rescue ActiveRecord::RecordNotUnique
      duplicate(event)
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record.errors.of_kind?(:stripe_event_id, :taken)

      duplicate(event)
    end

    def duplicate(event)
      Rails.logger.info("[stripe] duplicate event #{event.id} ignored")
      nil
    end

    def webhook_secret
      Rails.application.credentials.dig(:stripe, :webhook_secret) ||
        ENV.fetch("STRIPE_WEBHOOK_SECRET", nil)
    end
  end
end
