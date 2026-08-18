# frozen_string_literal: true

module AuthenticationHelpers
  # Signs in and, for request specs, establishes the active team the same way a
  # real request would — by putting it in the session.
  def sign_in_as(user, team: nil)
    sign_in(user)
    switch_team(team) if team
    user
  end

  def switch_team(team)
    post team_switch_path(team)
  end

  # System specs drive the UI, so they sign in through the real form.
  def sign_in_through_form(user, password: "password1234")
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Sign in"
  end
end
