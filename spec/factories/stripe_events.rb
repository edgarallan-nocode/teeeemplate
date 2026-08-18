# frozen_string_literal: true

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
FactoryBot.define do
  factory :stripe_event do
    sequence(:stripe_event_id) { |n| "evt_test_#{n}" }
    event_type { "customer.subscription.updated" }
    payload { { "id" => stripe_event_id, "type" => event_type } }

    trait :processed do
      processed_at { Time.current }
    end
  end
end
