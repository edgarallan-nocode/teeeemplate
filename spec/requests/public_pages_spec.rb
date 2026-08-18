# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Public pages" do
  it "renders the landing page for a signed-out visitor" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("A SaaS foundation")
  end

  it "sends a signed-in user to their dashboard" do
    user = create(:user, :with_team)
    sign_in user

    get root_path
    expect(response).to redirect_to(dashboard_path)
  end

  it "renders pricing from config/plans.yml" do
    get pricing_path

    expect(response).to have_http_status(:ok)
    Plan.all.each { |plan| expect(response.body).to include(plan.name) }
  end

  it "renders the legal stubs" do
    get terms_path
    expect(response).to have_http_status(:ok)

    get privacy_path
    expect(response).to have_http_status(:ok)
  end
end
