# frozen_string_literal: true

module Billing
  # Does the real work behind a webhook. The endpoint only records the event and
  # returns 200; everything that could be slow or could fail happens here.
  class ProcessStripeEventJob < ApplicationJob
    queue_as :critical

    retry_on Stripe::RateLimitError, wait: :polynomially_longer, attempts: 5
    retry_on Stripe::APIConnectionError, wait: :polynomially_longer, attempts: 5

    discard_on ActiveRecord::RecordNotFound

    def perform(stripe_event_record_id)
      record = StripeEvent.find(stripe_event_record_id)

      # A retry after a partial success must not apply the change twice.
      return if record.processed?

      Billing::ProcessStripeEvent.call(stripe_event: record)
    end
  end
end
