# frozen_string_literal: true

# == Schema Information
#
# Table name: teams
#
#  id                 :bigint           not null, primary key
#  name               :string           not null
#  slug               :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  stripe_customer_id :string
#
# Indexes
#
#  index_teams_on_slug                (slug) UNIQUE
#  index_teams_on_stripe_customer_id  (stripe_customer_id) UNIQUE
#
class Team < ApplicationRecord
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :invitations, class_name: "TeamInvitation", dependent: :destroy
  has_many :projects, dependent: :destroy
  has_one :subscription, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
  validates :slug, presence: true,
                   uniqueness: { case_sensitive: false },
                   length: { maximum: 60 },
                   format: {
                     with: /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/,
                     message: "may only contain lowercase letters, numbers and hyphens"
                   }

  before_validation :generate_slug, on: :create

  scope :search, ->(term) {
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("name ILIKE :q OR slug ILIKE :q", q: pattern)
  }

  def owners = users.merge(Membership.owner)

  def owner_memberships = memberships.owner

  def seat_count = memberships.count

  # Reads local state only. Never call Stripe to answer this — the webhook is
  # what keeps it true, and a request must not depend on Stripe being up.
  def subscription_active? = subscription&.active? || false

  def to_param = slug

  private

  def generate_slug
    return if slug.present?

    base = name.to_s.parameterize.presence || "team"
    base = base.first(50)
    candidate = base
    suffix = 1

    while self.class.exists?(slug: candidate)
      suffix += 1
      candidate = "#{base}-#{suffix}"
    end

    self.slug = candidate
  end
end
