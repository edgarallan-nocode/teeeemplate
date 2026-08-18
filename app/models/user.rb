# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  admin                  :boolean          default(FALSE), not null
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  first_name             :string
#  last_name              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  last_team_id           :bigint
#
# Indexes
#
#  index_users_on_admin                 (admin) WHERE admin
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_last_team_id          (last_team_id)
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (last_team_id => teams.id) ON DELETE => nullify
#
class User < ApplicationRecord
  # No :confirmable. An account is usable the moment it is created; email
  # addresses are not verified. See the RemoveConfirmableFromUsers migration
  # for what that trades away and how it is compensated for.
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :validatable, :trackable

  has_many :memberships, dependent: :destroy
  has_many :teams, through: :memberships
  has_many :owned_projects, class_name: "Project", foreign_key: :created_by_id,
                            dependent: :nullify, inverse_of: :created_by
  has_many :sent_invitations, class_name: "TeamInvitation", foreign_key: :invited_by_id,
                              dependent: :destroy, inverse_of: :invited_by
  has_many :impersonation_events, dependent: :destroy
  has_many :performed_impersonations, class_name: "ImpersonationEvent",
                                      foreign_key: :admin_id, dependent: :destroy,
                                      inverse_of: :admin

  belongs_to :last_team, class_name: "Team", optional: true

  validates :first_name, :last_name, length: { maximum: 100 }

  normalizes :email, with: ->(email) { email.to_s.strip.downcase }

  scope :admins, -> { where(admin: true) }
  scope :search, ->(term) {
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("email ILIKE :q OR first_name ILIKE :q OR last_name ILIKE :q", q: pattern)
  }

  def name
    [ first_name, last_name ].compact_blank.join(" ").presence || email
  end

  def initials
    parts = [ first_name, last_name ].compact_blank
    return email.first(2).upcase if parts.empty?

    parts.map { |part| part.first.upcase }.join
  end

  def membership_for(team)
    return nil if team.nil?

    memberships.find_by(team_id: team.id)
  end

  def member_of?(team) = membership_for(team).present?

  # Teams this user solely owns. Blocks account deletion when other people would
  # be stranded without an owner.
  def solely_owned_teams
    teams.merge(Membership.owner)
         .select { |team| team.memberships.owner.count == 1 }
  end

  # All Devise mail goes through Active Job. Nothing in the request cycle waits
  # on SES.
  def send_devise_notification(notification, *args)
    devise_mailer.public_send(notification, self, *args).deliver_later
  end
end
