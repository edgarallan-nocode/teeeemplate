# frozen_string_literal: true

# Local mirror of the team's Stripe subscription. It is written only by
# Billing::ProcessStripeEvent, so the webhook is the single source of truth and
# the request path never has to call Stripe to answer "is this team paid?".
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
class Subscription < ApplicationRecord
  include TenantScoped

  # Stripe's own status vocabulary, stored verbatim so there is nothing to
  # translate when reading the dashboard next to the database.
  STATUSES = %w[
    incomplete incomplete_expired trialing active
    past_due canceled unpaid paused
  ].freeze

  # Statuses that should grant access to paid features.
  ENTITLED_STATUSES = %w[trialing active past_due].freeze

  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validates :quantity, numericality: { greater_than_or_equal_to: 0 }

  scope :entitled, -> { where(status: ENTITLED_STATUSES) }

  def active? = ENTITLED_STATUSES.include?(status)

  def trialing? = status == "trialing"

  def past_due? = status == "past_due"

  def canceled? = status == "canceled"

  def plan = Plan.find(plan_key)

  def plan_name = plan&.name || plan_key.presence || "Unknown plan"

  def status_label
    return "Canceling #{current_period_end&.to_date&.to_fs(:long)}" if cancel_at_period_end && active?

    status.tr("_", " ").capitalize
  end
end
