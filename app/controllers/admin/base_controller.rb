# frozen_string_literal: true

module Admin
  # Platform administration.
  #
  # Gated on User#admin alone. It is not a team role and it does not inherit
  # anything from team membership — an owner of their own team has no admin
  # access, and an admin has no special power inside a team they do not belong
  # to beyond what is read-only here.
  class BaseController < ApplicationController
    skip_team_requirement!

    layout "admin"

    # Order matters. While impersonating, Current.user is the *target*, who is
    # not an admin — so the admin check would fire first and produce a generic
    # "not allowed". Checking impersonation first gives the real reason, and
    # still blocks the escalation either way.
    before_action :block_admin_while_impersonating
    before_action :require_platform_admin

    private

    def require_platform_admin
      return if Current.user&.admin?

      raise Pundit::NotAuthorizedError, "platform administration"
    end

    def block_admin_while_impersonating
      return unless impersonating?

      redirect_to root_path, alert: "Stop impersonating before using the admin area."
    end
  end
end
