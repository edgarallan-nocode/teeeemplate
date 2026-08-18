# frozen_string_literal: true

require "rails_helper"

# End-to-end through the real UI. These are the flows a person actually
# performs, exercised the way they perform them.
RSpec.describe "Team workflow" do
  let(:password) { "password1234" }

  def sign_in_through_form(user)
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Sign in"
  end

  it "creates a team, adds a project, and scopes it to that team" do
    user = create(:user)
    sign_in_through_form(user)

    expect(page).to have_content("Create a team")
    fill_in "Team name", with: "Acme Widgets"
    click_button "Create team"

    expect(page).to have_content("Acme Widgets is ready")

    click_link "New project"
    fill_in "Name", with: "First project"
    fill_in "Description", with: "Belongs to Acme Widgets."
    click_button "Create Project"

    expect(page).to have_content("Project created")
    expect(page).to have_content("First project")
    expect(Project.sole.team.name).to eq("Acme Widgets")
  end

  it "switches between teams and shows different data" do
    user = create(:user)
    alpha = create(:team, name: "Alpha Team")
    beta  = create(:team, name: "Beta Team")
    create(:membership, :owner, user: user, team: alpha)
    create(:membership, :owner, user: user, team: beta)
    create(:project, team: alpha, name: "Alpha only")
    create(:project, team: beta,  name: "Beta only")

    sign_in_through_form(user)
    visit projects_path

    expect(page).to have_content("Alpha only").or have_content("Beta only")

    # Switch explicitly rather than through the dropdown, which needs JS.
    page.driver.post(team_switch_path(beta))
    visit projects_path

    expect(page).to have_content("Beta only")
    expect(page).to have_no_content("Alpha only")
  end

  it "invites someone, and they accept and land in the team" do
    owner = create(:user)
    team = create(:team, name: "Inviting Co")
    create(:membership, :owner, user: owner, team: team)

    sign_in_through_form(owner)
    visit team_members_path(team)

    fill_in "Email", with: "invitee@example.com"
    click_button "Send invitation"

    expect(page).to have_content("Invitation sent to invitee@example.com")

    invitation = team.invitations.pending.sole

    # The sign-out button lives in a dropdown that JavaScript reveals, so the
    # rack_test driver cannot click it. Sign out through the route instead.
    page.driver.submit :delete, destroy_user_session_path, {}

    invitee = create(:user, email: "invitee@example.com")
    sign_in_through_form(invitee)

    visit invitation_path(invitation.token)
    expect(page).to have_content("Join Inviting Co")

    click_button "Accept invitation"
    expect(page).to have_content("Welcome to Inviting Co")
    expect(invitee.reload.teams).to include(team)
  end

  it "refuses an invitation opened by the wrong account" do
    team = create(:team, name: "Wrong Account Co")
    create(:membership, :owner, team: team)
    invitation = create(:team_invitation, team: team, email: "intended@example.com")

    wrong = create(:user, :with_team, email: "someone-else@example.com")
    sign_in_through_form(wrong)
    visit invitation_path(invitation.token)

    expect(page).to have_content("was sent to")
    expect(page).to have_no_button("Accept invitation")
  end

  it "signs up and lands straight in team creation" do
    visit new_user_registration_path

    fill_in "First name", with: "Newly"
    fill_in "Last name", with: "Registered"
    fill_in "Email", with: "newly@example.com"
    fill_in "Password", with: password
    fill_in "Confirm password", with: password
    click_button "Create account"

    # No confirmation step and no second sign-in: the account is usable at once.
    expect(User.find_by(email: "newly@example.com")).to be_present
    expect(page).to have_content("Create a team")
  end
end
