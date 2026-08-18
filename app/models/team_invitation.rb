# frozen_string_literal: true

# == Schema Information
#
# Table name: team_invitations
#
#  id             :bigint           not null, primary key
#  accepted_at    :datetime
#  email          :string           not null
#  expires_at     :datetime         not null
#  role           :integer          default(0), not null
#  token          :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  accepted_by_id :bigint
#  invited_by_id  :bigint           not null
#  team_id        :bigint           not null
#
# Indexes
#
#  index_team_invitations_on_accepted_by_id          (accepted_by_id)
#  index_team_invitations_on_invited_by_id           (invited_by_id)
#  index_team_invitations_on_team_id                 (team_id)
#  index_team_invitations_on_token                   (token) UNIQUE
#  index_team_invitations_pending_on_team_and_email  (team_id,email) UNIQUE WHERE (accepted_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (accepted_by_id => users.id)
#  fk_rails_...  (invited_by_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#
class TeamInvitation < ApplicationRecord
  EXPIRY = 14.days

  enum :role, { member: 0, admin: 1, owner: 2 }, validate: true

  include TenantScoped

  belongs_to :invited_by, class_name: "User"
  belongs_to :accepted_by, class_name: "User", optional: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :token, presence: true, uniqueness: true
  validate :recipient_is_not_already_a_member, on: :create

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  before_validation :assign_token, on: :create
  before_validation :assign_expiry, on: :create

  scope :pending, -> { where(accepted_at: nil).where(expires_at: Time.current..) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :expired, -> { where(accepted_at: nil).where(expires_at: ...Time.current) }

  def accepted? = accepted_at.present?
  def expired? = expires_at.present? && expires_at.past?
  def pending? = !accepted? && !expired?

  private

  def assign_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def assign_expiry
    self.expires_at ||= EXPIRY.from_now
  end

  def recipient_is_not_already_a_member
    return if team.blank? || email.blank?
    return unless team.users.exists?(email: email)

    errors.add(:email, "is already a member of this team")
  end
end
