# frozen_string_literal: true

module Teams
  class LeavesController < ApplicationController
    skip_team_requirement!

    def create
      team = set_team_from_params

      # Authorized on membership, not on :leave?. The last-owner rule is
      # enforced by Teams::Leave and by the model, and both can say *why* —
      # a bare policy refusal would only produce "you are not allowed to do
      # that", which is true but useless. TeamPolicy#leave? still decides
      # whether the button is offered in the first place.
      authorize team, :show?, policy_class: TeamPolicy

      result = ::Teams::Leave.call(team: team, user: Current.user)

      if result.success?
        session.delete(:team_id)
        redirect_to root_path, notice: "You have left #{team.name}.", status: :see_other
      else
        redirect_to team_members_path(team), alert: result.error, status: :see_other
      end
    end
  end
end
