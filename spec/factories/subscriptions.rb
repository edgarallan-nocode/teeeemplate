# frozen_string_literal: true

# == Schema Information
#
# Table name: subscriptions
#
#  id                          :bigint           not null, primary key
#  cancel_at_period_end        :boolean          default(FALSE), not null
#  canceled_at                 :datetime
#  current_period_end          :datetime
#  plan_key                    :string
#  quantity                    :integer          default(1), not null
#  status                      :string           default("incomplete"), not null
#  trial_ends_at               :datetime
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  stripe_price_id             :string
#  stripe_subscription_id      :string           not null
#  stripe_subscription_item_id :string
#  team_id                     :bigint           not null
#
# Indexes
#
#  index_subscriptions_on_status                  (status)
#  index_subscriptions_on_stripe_subscription_id  (stripe_subscription_id) UNIQUE
#  index_subscriptions_on_team_id                 (team_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#
FactoryBot.define do
  factory :subscription do
    team
    sequence(:stripe_subscription_id) { |n| "sub_test_#{n}" }
    sequence(:stripe_subscription_item_id) { |n| "si_test_#{n}" }
    stripe_price_id { "price_starter_monthly" }
    plan_key { "starter" }
    status { "active" }
    quantity { 1 }
    current_period_end { 30.days.from_now }

    trait(:trialing)  { status { "trialing" }; trial_ends_at { 14.days.from_now } }
    trait(:past_due)  { status { "past_due" } }
    trait(:canceled)  { status { "canceled" }; canceled_at { Time.current } }
    trait(:canceling) { cancel_at_period_end { true } }
  end
end
