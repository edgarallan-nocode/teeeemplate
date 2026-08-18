# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Dashboard" do
  it "requires authentication" do
    get dashboard_path
    expect(response).to redirect_to(new_user_session_path)
  end

  it "sends a user with no team to team creation" do
    sign_in create(:user)

    get dashboard_path
    expect(response).to redirect_to(new_team_path)
  end

  it "renders the active team" do
    tenant = create_tenant(name: "Northwind")
    sign_in tenant.owner

    get dashboard_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Northwind")
  end

  it "shows only the active team's projects" do
    a = create_tenant
    b = create_tenant
    create(:project, team: a.team, name: "Visible project")
    create(:project, team: b.team, name: "Hidden project")

    sign_in a.owner
    get dashboard_path

    expect(response.body).to include("Visible project")
    expect(response.body).not_to include("Hidden project")
  end
end
