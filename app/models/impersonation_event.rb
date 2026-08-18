# frozen_string_literal: true

# Audit record for support impersonation. One row is written when an admin
# starts impersonating and closed when they stop, so there is always a record of
# who acted as whom, from where, and for how long.
# == Schema Information
#
# Table name: impersonation_events
#
#  id         :bigint           not null, primary key
#  ended_at   :datetime
#  ip_address :string
#  reason     :string
#  started_at :datetime         not null
#  user_agent :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  admin_id   :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_impersonation_events_on_admin_id                 (admin_id)
#  index_impersonation_events_on_admin_id_and_started_at  (admin_id,started_at)
#  index_impersonation_events_on_ended_at                 (ended_at)
#  index_impersonation_events_on_user_id                  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (admin_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class ImpersonationEvent < ApplicationRecord
  belongs_to :admin, class_name: "User"
  belongs_to :user

  validates :started_at, presence: true
  validate :admin_must_be_an_admin

  scope :open, -> { where(ended_at: nil) }
  scope :recent, -> { order(started_at: :desc) }

  def active? = ended_at.nil?

  def duration
    return nil if ended_at.nil?

    ended_at - started_at
  end

  def close!
    update!(ended_at: Time.current) if active?
  end

  private

  def admin_must_be_an_admin
    return if admin.nil? || admin.admin?

    errors.add(:admin, "must be a platform administrator")
  end
end
