# frozen_string_literal: true

module TenancyHelpers
  # Sets Current the way ApplicationController would, for specs that exercise
  # models, policies, or services directly rather than through a request.
  def acting_as(user, team: nil)
    membership = team ? user.memberships.find_by(team: team) : user.memberships.first
    Current.user = user
    Current.true_user = user
    Current.team = team || membership&.team
    Current.membership = membership
    yield if block_given?
  ensure
    Current.reset if block_given?
  end

  # Builds a complete, independent tenant: a team, an owner, and a member.
  # Used by cross-team isolation specs, which need two of everything.
  def create_tenant(name: nil, plan: nil)
    team = create(:team, name: name || Faker::Company.unique.name)
    owner = create(:user)
    member = create(:user)
    create(:membership, user: owner, team: team, role: :owner)
    create(:membership, user: member, team: team, role: :member)
    create(:subscription, team: team, plan_key: plan) if plan

    Struct.new(:team, :owner, :member, keyword_init: true)
          .new(team: team, owner: owner, member: member)
  end
end
