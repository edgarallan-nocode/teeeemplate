# frozen_string_literal: true

# The webhook idempotency ledger. One row per Stripe event id, enforced by a
# unique index — a redelivered event fails to insert, and that failure is how
# the endpoint recognises a duplicate rather than reprocessing it.
# == Schema Information
#
# Table name: stripe_events
#
#  id              :bigint           not null, primary key
#  attempts        :integer          default(0), not null
#  error_message   :text
#  event_type      :string           not null
#  failed_at       :datetime
#  payload         :jsonb            not null
#  processed_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  stripe_event_id :string           not null
#
# Indexes
#
#  index_stripe_events_on_event_type       (event_type)
#  index_stripe_events_on_processed_at     (processed_at)
#  index_stripe_events_on_stripe_event_id  (stripe_event_id) UNIQUE
#
class StripeEvent < ApplicationRecord
  validates :stripe_event_id, presence: true, uniqueness: true
  validates :event_type, presence: true

  scope :unprocessed, -> { where(processed_at: nil, failed_at: nil) }
  scope :failed, -> { where.not(failed_at: nil) }

  def processed? = processed_at.present?

  def mark_processed!
    update!(processed_at: Time.current, failed_at: nil, error_message: nil)
  end

  def mark_failed!(error)
    update!(
      failed_at: Time.current,
      error_message: error.message.truncate(1_000),
      attempts: attempts + 1
    )
  end

  # Rehydrates the raw payload into a Stripe object so handlers get the same
  # interface whether they run inline or from a retried job.
  def to_stripe_event
    Stripe::Event.construct_from(payload.deep_symbolize_keys)
  end
end
