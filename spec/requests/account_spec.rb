# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Account" do
  let(:user) { create(:user, :with_team) }

  before { sign_in user }

  it "updates the profile" do
    patch account_path, params: { user: { first_name: "Updated", last_name: "Name" } }

    expect(user.reload.first_name).to eq("Updated")
  end

  it "changes the password when the current one is given" do
    patch account_path, params: {
      user: {
        current_password: "password1234",
        password: "a-brand-new-password", password_confirmation: "a-brand-new-password"
      }
    }

    expect(user.reload.valid_password?("a-brand-new-password")).to be(true)
  end

  it "refuses a password change without the current password" do
    patch account_path, params: {
      user: { current_password: "wrong", password: "nope-nope-nope",
              password_confirmation: "nope-nope-nope" }
    }

    expect(user.reload.valid_password?("password1234")).to be(true)
  end

  describe "deletion" do
    it "requires the correct password" do
      expect {
        delete account_path, params: { current_password: "wrong-password" }
      }.not_to change(User, :count)

      expect(flash[:alert]).to match(/password is incorrect/i)
    end

    it "deletes the account and any team the user solely owns alone" do
      solo_team = user.teams.first

      expect {
        delete account_path, params: { current_password: "password1234" }
      }.to change(User, :count).by(-1)

      expect(Team.exists?(solo_team.id)).to be(false)
    end

    it "refuses when the user is the only owner of a team with other members" do
      tenant = create_tenant
      sign_out user
      sign_in tenant.owner

      expect {
        delete account_path, params: { current_password: "password1234" }
      }.not_to change(User, :count)

      expect(flash[:alert]).to match(/only owner/i)
    end

    it "allows deletion once another owner exists" do
      tenant = create_tenant
      create(:membership, :owner, team: tenant.team)
      sign_out user
      sign_in tenant.owner

      expect {
        delete account_path, params: { current_password: "password1234" }
      }.to change(User, :count).by(-1)

      expect(Team.exists?(tenant.team.id)).to be(true)
    end
  end
end
