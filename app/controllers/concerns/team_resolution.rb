# frozen_string_literal: true

# Resolves the active team for the request and puts it on Current.
#
# The team id in the session is never trusted on its own. It is always looked up
# *through the current user's memberships*, so tampering with the session gets
# you nothing — the lookup simply fails and falls back.
module TeamResolution
  extend ActiveSupport::Concern

  included do
    # class_attribute rather than a class ivar so subclasses inherit the opt-out
    # — Public::PagesController must not have to repeat what its base class
    # already declared.
    class_attribute :skip_team_requirement, instance_writer: false, default: false

    before_action :set_current_team
    before_action :require_team

    helper_method :current_team, :current_membership, :available_teams
  end

  private

  def set_current_team
    Current.team = current_team
    Current.membership = current_membership
  end

  def current_team
    return @current_team if defined?(@current_team)

    @current_team = resolve_team
  end

  def resolve_team
    return nil if Current.user.nil?

    memberships = Current.user.memberships

    # Session first, then the team the user was last in, then anything they
    # belong to. Every branch goes through the membership join, so an unrelated
    # team id can never resolve.
    membership =
      memberships.find_by(team_id: session[:team_id]) ||
      memberships.find_by(team_id: Current.user.last_team_id) ||
      memberships.ordered.first

    membership&.team
  end

  def current_membership
    return nil if Current.user.nil? || current_team.nil?

    @current_membership ||= Current.user.memberships.find_by(team_id: current_team.id)
  end

  def available_teams
    return Team.none if Current.user.nil?

    @available_teams ||= Current.user.teams.order(:name)
  end

  # A signed-in user with no team cannot do anything useful, so send them to
  # create one. Controllers that must work without a team opt out.
  def require_team
    return if Current.user.nil?
    return if current_team.present?
    return if self.class.skip_team_requirement

    redirect_to new_team_path, notice: "Create a team to get started."
  end

  # Resolves a team from a nested route (:team_id) or a member route (:id) and
  # makes it the active team.
  #
  # This exists because the URL and the session can disagree — following a link
  # to /teams/other-team/members while the session still points at this team
  # would otherwise render that team's data while policies evaluated against
  # this team's membership. The URL wins: what you are looking at is what you
  # are acting on.
  #
  # The lookup still goes through the user's own memberships, so an unrelated
  # slug is not found rather than switched to.
  def set_team_from_params(param = :team_id)
    team = Current.user.teams.find_by!(slug: params[param])
    switch_to_team(team) unless team == current_team
    team
  end

  # Persists the active team for this session and for the next one.
  def switch_to_team(team)
    session[:team_id] = team.id
    Current.user.update_column(:last_team_id, team.id)
    @current_team = team
    @current_membership = nil
    Current.team = team
    Current.membership = current_membership
  end

  class_methods do
    # Controllers that render before a team exists (team creation, invitation
    # acceptance, account settings) call this.
    def skip_team_requirement!
      self.skip_team_requirement = true
    end
  end
end
