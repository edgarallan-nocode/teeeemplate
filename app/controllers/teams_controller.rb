# frozen_string_literal: true

class TeamsController < ApplicationController
  # A user with no team has to be able to reach the creation form, so this
  # controller cannot require one.
  skip_team_requirement!

  before_action :set_team, only: %i[edit update destroy]

  def new
    @team = Team.new
    authorize @team
  end

  def create
    authorize Team

    result = Teams::Create.call(name: team_params[:name], owner: Current.user)

    if result.success?
      switch_to_team(result.value)
      redirect_to dashboard_path, notice: "#{result.value.name} is ready."
    else
      @team = result.value || Team.new(team_params)
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize @team
  end

  def update
    authorize @team

    if @team.update(team_params)
      redirect_to edit_team_path(@team), notice: "Team settings saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @team
    name = @team.name
    @team.destroy!

    # The user may still belong to other teams; resolve to one of them.
    session.delete(:team_id)
    Current.user.update_column(:last_team_id, Current.user.memberships.reload.first&.team_id)

    redirect_to root_path, notice: "#{name} was deleted.", status: :see_other
  end

  private

  # Looked up through the current user's memberships, so a team they do not
  # belong to is not found rather than forbidden. Editing a team also makes it
  # the active one, so the policy reads the right membership.
  def set_team
    @team = set_team_from_params(:id)
  end

  def team_params
    params.expect(team: %i[name slug])
  end
end
