# frozen_string_literal: true

# EXAMPLE RESOURCE.
#
# Project exists to demonstrate the tenant-scoping pattern end to end: this
# model, ProjectPolicy, Projects::Scoped query object, ProjectsController, the
# views, and the cross-team isolation specs. Copy the shape; delete the model
# when you start a real application.
# == Schema Information
#
# Table name: projects
#
#  id            :bigint           not null, primary key
#  archived_at   :datetime
#  description   :text
#  name          :string           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  created_by_id :bigint
#  team_id       :bigint           not null
#
# Indexes
#
#  index_projects_on_created_by_id           (created_by_id)
#  index_projects_on_team_id                 (team_id)
#  index_projects_on_team_id_and_created_at  (team_id,created_at)
#  index_projects_on_team_id_and_name        (team_id,name)
#
# Foreign Keys
#
#  fk_rails_...  (created_by_id => users.id)
#  fk_rails_...  (team_id => teams.id)
#
class Project < ApplicationRecord
  include TenantScoped

  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 2_000 }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :search, ->(term) {
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("name ILIKE :q OR description ILIKE :q", q: pattern)
  }

  def archived? = archived_at.present?

  def archive! = update!(archived_at: Time.current)

  def unarchive! = update!(archived_at: nil)
end
