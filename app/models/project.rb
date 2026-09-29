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
  # The pictures dropped into the description. See that file.
  include EditorImages

  belongs_to :created_by, class_name: "User", optional: true

  validates :name, presence: true, length: { maximum: 120 }
  # `description` is HTML from the rich text editor and `content` is the editor's
  # JSON for the same text. The HTML is canonical — it renders, it is searched, it
  # is summarised in a list — and it goes through RichText before it is saved, so
  # a row never holds anything a template would have to refuse. The JSON is a
  # convenience for reopening the editor as it was left; when it is missing the
  # editor rebuilds it from the HTML.
  validates :description, length: { maximum: 100_000 }

  # Sanitised before validation so the length limit applies to what is kept, and
  # so an empty editor (`<p></p>`) lands as no description rather than an empty tag.
  before_validation :sanitize_description, if: :description_changed?

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :recent, -> { order(created_at: :desc) }
  scope :search, ->(term) {
    next all if term.blank?

    pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
    where("name ILIKE :q OR description ILIKE :q", q: pattern)
  }

  def archived? = archived_at.present?

  # The description's words without the markup — what a list row shows.
  def text = RichText.text(description)

  # The form posts the editor's JSON as a string; the column is jsonb. Parsed
  # here so a jsonb column never ends up holding a JSON *string*.
  def content=(value)
    super(value.is_a?(String) ? parse_content(value) : value)
  end

  def archive! = update!(archived_at: Time.current)

  def unarchive! = update!(archived_at: nil)

  private

  def sanitize_description
    self.description = RichText.blank?(description) ? nil : RichText.sanitize(description)
  end

  def parse_content(value)
    return nil if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError
    nil
  end
end
