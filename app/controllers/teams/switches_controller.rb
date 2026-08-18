# frozen_string_literal: true

module Teams
  class SwitchesController < ApplicationController
    skip_team_requirement!

    def create
      team = Current.user.teams.find_by!(slug: params[:team_id])
      authorize team, :switch?, policy_class: TeamPolicy

      switch_to_team(team)

      redirect_back fallback_location: dashboard_path,
                    notice: "Switched to #{team.name}."
    end
  end
end
