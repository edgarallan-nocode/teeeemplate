# frozen_string_literal: true

# Account settings for the signed-in user. Not team-scoped — a user's name,
# email and password belong to them, not to whichever team they are viewing.
class AccountController < ApplicationController
  skip_team_requirement!

  before_action :block_while_impersonating!, only: %i[destroy]

  def show
    @user = Current.user
    skip_authorization
  end

  def update
    @user = Current.user
    skip_authorization

    if password_change_requested?
      update_with_password
    else
      update_profile
    end
  end

  def confirm_delete
    @user = Current.user
    @blocking_teams = @user.solely_owned_teams.select { |team| team.memberships.count > 1 }
    skip_authorization
  end

  def destroy
    skip_authorization

    result = Users::DeleteAccount.call(user: Current.user, password: params[:current_password])

    if result.success?
      reset_session
      redirect_to root_path, notice: "Your account has been deleted.", status: :see_other
    else
      redirect_to confirm_delete_account_path, alert: result.error, status: :see_other
    end
  end

  private

  def password_change_requested? = params[:user][:password].present?

  def update_profile
    if @user.update(profile_params)
      redirect_to account_path, notice: "Account updated."
    else
      render :show, status: :unprocessable_content
    end
  end

  # Changing a password requires the current one, and keeps the session alive
  # afterwards so the user is not silently signed out.
  def update_with_password
    if @user.update_with_password(password_params)
      bypass_sign_in(@user)
      redirect_to account_path, notice: "Password changed."
    else
      render :show, status: :unprocessable_content
    end
  end

  def profile_params
    params.expect(user: %i[first_name last_name])
  end

  def password_params
    params.expect(user: %i[password password_confirmation current_password])
  end
end
