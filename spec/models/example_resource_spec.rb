# frozen_string_literal: true

require "rails_helper"

# Project is the disposable example, and `bin/remove-example` deletes it.
#
# The danger is drift: a core spec quietly starts using `create(:project)`
# because it is the handiest tenant-scoped model around, and months later
# removing the example takes real coverage with it. This spec fails the moment
# that happens, naming the file so it can be pointed at a permanent model
# instead.
RSpec.describe "the example resource" do
  # Files that bin/remove-example deletes or rewrites, and which may therefore
  # depend on Project freely.
  def example_owned = %w[
    spec/factories/projects.rb
    spec/requests/projects_spec.rb
    spec/policies/policies_spec.rb
    spec/requests/dashboard_spec.rb
    spec/system/team_workflow_spec.rb
    spec/models/example_resource_spec.rb
  ]

  it "is not depended on by any spec that outlives it" do
    offenders = Rails.root.glob("spec/**/*.rb").filter_map do |file|
      relative = file.relative_path_from(Rails.root).to_s
      next if example_owned.include?(relative)

      # Comments naming Project as an illustration are fine; code is not.
      code = file.read.lines.grep_v(/^\s*#/).join
      next unless code.match?(/\bProject\b|create\(:project|:project\b/)

      relative
    end

    expect(offenders).to be_empty, <<~MSG
      These specs reference the example Project resource but are not removed by
      bin/remove-example, so deleting the example would break or silently
      weaken them:

      #{offenders.map { |o| "  #{o}" }.join("\n")}

      Use a permanent tenant-scoped model (Membership, Subscription,
      TeamInvitation) instead, or add the file to bin/remove-example.
    MSG
  end

  it "is not depended on by application code outside its own files" do
    own = %w[
      app/models/project.rb
      app/policies/project_policy.rb
      app/controllers/projects_controller.rb
    ].freeze

    offenders = Rails.root.glob("app/**/*.rb").filter_map do |file|
      relative = file.relative_path_from(Rails.root).to_s
      next if own.include?(relative)

      # Comments naming Project as an illustration are fine; code is not.
      code = file.read.lines.grep_v(/^\s*#/).join
      next unless code.match?(/\bProject\b|\bprojects\b/)

      relative
    end

    # Team and User carry the association, and the dashboard reads it. All
    # three are handled by bin/remove-example.
    handled = %w[
      app/models/team.rb
      app/models/user.rb
      app/controllers/dashboard_controller.rb
      app/controllers/admin/teams_controller.rb
    ].freeze

    expect(offenders - handled).to be_empty, <<~MSG
      These files reference the example resource and are not handled by
      bin/remove-example:

      #{(offenders - handled).map { |o| "  #{o}" }.join("\n")}
    MSG
  end
end
