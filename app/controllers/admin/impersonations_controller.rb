# frozen_string_literal: true

module Admin
  # Starting and stopping support impersonation.
  #
  # This controller is the only way in. It cannot be reached while already
  # impersonating (BaseController blocks the whole admin area), the target is
  # authorized through Admin::UserPolicy#impersonate?, and both the start and
  # the stop are written to ImpersonationEvent.
  class ImpersonationsController < BaseController
    # Stopping has to work from inside an impersonated session, which is exactly
    # the state BaseController refuses. The banner's "stop" button posts here.
    skip_before_action :block_admin_while_impersonating, only: :destroy
    skip_before_action :require_platform_admin, only: :destroy

    def create
      user = User.find(params[:user_id])
      authorize user, :impersonate?, policy_class: Admin::UserPolicy

      result = Admin::StartImpersonation.call(
        admin: Current.user,
        user: user,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        reason: params[:reason].presence
      )

      if result.success?
        begin_session(user, result.value)
        redirect_to root_path, notice: "You are now impersonating #{user.name}."
      else
        redirect_to admin_user_path(user), alert: result.error
      end
    end

    def destroy
      skip_authorization

      Admin::StopImpersonation.call(
        event_id: session[:impersonation_event_id],
        admin: current_user
      )

      impersonated_id = session.delete(:impersonated_user_id)
      session.delete(:impersonation_event_id)
      session.delete(:team_id)

      destination = impersonated_id ? admin_user_path(impersonated_id) : admin_root_path
      redirect_to destination, notice: "Impersonation ended.", status: :see_other
    end

    private

    def begin_session(user, event)
      session[:impersonated_user_id] = user.id
      session[:impersonation_event_id] = event.id
      # Drop the admin's active team so the next request resolves the target's.
      session.delete(:team_id)
    end
  end
end
