# frozen_string_literal: true

require "rails_helper"

# A guard rail rather than a feature test.
#
# Multi-tenancy in this application is opt-in per model, which means a new model
# with a team_id column that forgets `include TenantScoped` would silently skip
# the whole mechanism. This spec makes that mistake fail CI.
RSpec.describe "tenant scoping" do
  # Join tables and infrastructure tables that carry a team_id but are not
  # themselves tenant-owned records would be listed here. There are none today.
  def exempt_tables = []

  def tenant_models
    Rails.application.eager_load!

    ApplicationRecord.descendants.select do |model|
      model.table_exists? &&
        model.column_names.include?("team_id") &&
        exempt_tables.exclude?(model.table_name)
    end
  end

  it "finds the models it is supposed to be guarding" do
    expect(tenant_models.map(&:name)).to include("Project", "Membership", "Subscription")
  end

  it "requires every model with a team_id to include TenantScoped" do
    missing = tenant_models.reject { |model| model.include?(TenantScoped) }

    expect(missing).to be_empty,
      "These models have a team_id but do not include TenantScoped: " \
      "#{missing.map(&:name).join(', ')}. Include the concern, or add the table " \
      "to #exempt_tables with a comment explaining why it is not tenant-owned."
  end

  it "requires every tenant model to validate that a team is present" do
    without_validation = tenant_models.reject do |model|
      record = model.new
      record.valid?
      record.errors.of_kind?(:team, :blank)
    end

    expect(without_validation).to be_empty
  end

  describe "TenantScoped behaviour" do
    it "assigns Current.team on create when no team is given" do
      team = create(:team)
      acting_as(create(:user), team: team) do
        Current.team = team
        expect(Project.create!(name: "Inferred").team).to eq(team)
      end
    end

    it "does not override an explicitly assigned team" do
      other = create(:team)
      acting_as(create(:user), team: create(:team)) do
        expect(Project.create!(name: "Explicit", team: other).team).to eq(other)
      end
    end

    it "refuses to save without any team at all" do
      Current.reset
      project = Project.new(name: "Homeless")
      expect(project).not_to be_valid
      expect(project.errors[:team]).to be_present
    end

    it "scopes with .for_team" do
      a = create(:project)
      b = create(:project)

      expect(Project.for_team(a.team)).to contain_exactly(a)
      expect(Project.for_team(b.team)).to contain_exactly(b)
    end
  end
end
