# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Projects" do
  describe "cross-team isolation" do
    it_behaves_like "a tenant-isolated resource" do
      let(:factory) { :project }
      let(:member_path) { ->(record) { project_path(record) } }
      let(:collection_path) { projects_path }
      let(:update_params) { { project: { name: "Hijacked" } } }
    end
  end

  describe "creating" do
    let(:tenant) { create_tenant }

    before { sign_in tenant.member }

    it "assigns the project to the active team, never to a team from params" do
      other = create_tenant

      # Even if a team_id is smuggled in, the record belongs to the active team:
      # the controller builds it from current_team.projects and team_id is not
      # a permitted parameter.
      post projects_path, params: {
        project: { name: "Smuggled", description: "x", team_id: other.team.id }
      }

      project = Project.find_by(name: "Smuggled")
      expect(project.team).to eq(tenant.team)
    end

    it "records who created it" do
      post projects_path, params: { project: { name: "Attributed" } }

      expect(Project.find_by(name: "Attributed").created_by).to eq(tenant.member)
    end

    it "re-renders with errors when invalid" do
      post projects_path, params: { project: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("stopped this from being saved")
    end
  end

  describe "authorization" do
    let(:tenant) { create_tenant }
    let!(:project) { create(:project, team: tenant.team) }

    it "lets a member create and edit" do
      sign_in tenant.member

      patch project_path(project), params: { project: { name: "Renamed" } }
      expect(project.reload.name).to eq("Renamed")
    end

    it "does not let a member destroy" do
      sign_in tenant.member

      delete project_path(project)

      expect(response).to have_http_status(:found)
      expect(Project.exists?(project.id)).to be(true)
    end

    it "lets an owner destroy" do
      sign_in tenant.owner

      delete project_path(project)

      expect(Project.exists?(project.id)).to be(false)
    end
  end

  describe "search" do
    it "filters within the team only" do
      mine = create_tenant
      theirs = create_tenant
      create(:project, team: mine.team, name: "Alpha report")
      create(:project, team: theirs.team, name: "Alpha secret")

      sign_in mine.owner
      get projects_path, params: { q: "Alpha" }

      expect(response.body).to include("Alpha report")
      expect(response.body).not_to include("Alpha secret")
    end
  end
end
