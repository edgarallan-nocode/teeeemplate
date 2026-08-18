# frozen_string_literal: true

module Public
  # Pages anyone can see. No authentication, no team, no Pundit — the whole
  # point is that these render for a signed-out visitor.
  class BaseController < ApplicationController
    skip_team_requirement!

    skip_before_action :authenticate_user!
    skip_before_action :require_team
  end
end
