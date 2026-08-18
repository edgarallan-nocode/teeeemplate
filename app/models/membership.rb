# frozen_string_literal: true

# A user's role inside one team. This is the only place team-level permission
# level is stored; policies read it, nothing else writes it directly.
# == Schema Information
#
# Table name: memberships
#
#  id         :bigint           not null, primary key
#  role       :integer          default(0), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  team_id    :bigint           not null
#  user_id    :bigint           not null
#
# Indexes
#
#  index_memberships_on_team_id              (team_id)
#  index_memberships_on_team_id_and_role     (team_id,role)
#  index_memberships_on_user_id              (user_id)
#  index_memberships_on_user_id_and_team_id  (user_id,team_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (team_id => teams.id)
#  fk_rails_...  (user_id => users.id)
#
class Membership < ApplicationRecord
  # Integer values are ordered on purpose so "admin or above" is a comparison
  # rather than a list of role names that has to be kept in sync.
  enum :role, { member: 0, admin: 1, owner: 2 }, validate: true

  include TenantScoped

  belongs_to :user

  validates :user_id, uniqueness: { scope: :team_id }
  validate :team_must_keep_an_owner, on: :update
  before_destroy :ensure_team_keeps_an_owner

  after_commit :sync_billing_seats, on: %i[create destroy]

  scope :ordered, -> { order(role: :desc, created_at: :asc) }

  ROLE_LABELS = {
    "owner" => "Owner",
    "admin" => "Admin",
    "member" => "Member"
  }.freeze

  def role_label = ROLE_LABELS.fetch(role)

  def at_least?(other_role)
    self.class.roles.fetch(role.to_s) >= self.class.roles.fetch(other_role.to_s)
  end

  def admin_or_above? = at_least?(:admin)

  def last_owner?
    owner? && team.memberships.owner.where.not(id: id).none?
  end

  private

  # A team without an owner has no one who can manage billing or delete it, so
  # the invariant is enforced at the model rather than in each service.
  def team_must_keep_an_owner
    return unless role_changed?(from: "owner")
    return if team.memberships.owner.where.not(id: id).any?

    errors.add(:role, "cannot be changed: a team must always have at least one owner")
  end

  def ensure_team_keeps_an_owner
    return unless owner?

    # When the team itself is being destroyed, its memberships go with it and
    # the invariant no longer applies. `destroyed_by_association` is set by
    # Rails during a dependent: :destroy cascade — without this check, deleting
    # a team would be blocked by its own owner's membership.
    return if destroyed_by_association.present?
    return if team.destroyed? || team.marked_for_destruction?
    return if team.memberships.owner.where.not(id: id).any?

    errors.add(:base, "A team must always have at least one owner")
    throw :abort
  end

  # Seats are billed per member, so any change to the roster has to reach
  # Stripe. The job recomputes from the database, so a retry is harmless.
  def sync_billing_seats
    return if team.nil? || team.destroyed?

    Billing::SyncSeatsJob.perform_later(team_id)
  end
end
