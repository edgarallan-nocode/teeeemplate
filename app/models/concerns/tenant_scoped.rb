# frozen_string_literal: true

# Every tenant-owned model includes this. It is the single mechanism for
# multi-tenancy in this application — there is no default scope, no thread-local
# query filter, and no gem doing it invisibly.
#
# The rule that makes it work lives in the controllers, not here:
#
#   NEVER   Project.find(params[:id])
#   ALWAYS  Current.team.projects.find(params[:id])
#
# Starting every query from the team means a record belonging to another team is
# not "forbidden", it simply does not exist for this request — the lookup raises
# RecordNotFound and Rails renders 404. That is the correct answer: a 403 would
# confirm the record exists.
#
# Pundit still runs on top of this. Scoping answers "which records exist for
# me"; the policy answers "what may I do with them".
module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :team

    validates :team, presence: true

    # Convenience for records built outside a team-scoped association, e.g. in
    # a service or a console session where Current.team is already set.
    before_validation :assign_current_team, on: :create

    scope :for_team, ->(team) { where(team: team) }
  end

  class_methods do
    # Marker used by spec/models/tenant_scoping_spec.rb to assert that every
    # model with a team_id column actually opted into this concern.
    def tenant_scoped? = true
  end

  private

  def assign_current_team
    self.team ||= Current.team
  end
end
