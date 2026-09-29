# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Style guide" do
  # Rails.env.local? is true in test, so the open path is the default here.
  # The production branch is exercised by swapping the inquirer.
  def in_production
    allow(Rails).to receive(:env).and_return(ActiveSupport::EnvironmentInquirer.new("production"))
  end

  describe "in development and test" do
    it "renders for a visitor who is not signed in" do
      get styleguide_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Style guide")
    end

    it "renders without a team, so a signed-in user with none is not redirected" do
      sign_in create(:user)

      get styleguide_path

      expect(response).to have_http_status(:ok)
      expect(response).not_to redirect_to(new_team_path)
    end

    it "shows the components it documents" do
      get styleguide_path

      expect(response.body).to include("btn--primary")
      expect(response.body).to include("badge--positive")
      expect(response.body).to include('data-controller="tabs"')
    end
  end

  describe "in production" do
    before { in_production }

    it "is not found for a visitor who is not signed in" do
      get styleguide_path

      expect(response).to have_http_status(:not_found)
    end

    # 404 rather than 403: a page that is not yours to see should not confirm
    # that it exists.
    it "is not found for an ordinary signed-in user" do
      sign_in create(:user, :with_team)

      get styleguide_path

      expect(response).to have_http_status(:not_found)
    end

    it "renders for a platform admin" do
      sign_in create(:user, :admin)

      get styleguide_path

      expect(response).to have_http_status(:ok)
    end
  end
end
