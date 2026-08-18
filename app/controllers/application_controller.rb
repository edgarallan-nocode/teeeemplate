# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include SetsCurrentAttributes
  include Impersonation
  include TeamResolution
  include Pagination

  # Only modern browsers. Keeps the CSS and JS free of legacy fallbacks.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Nothing renders without an explicit authorization decision. Forgetting a
  # policy call is a test failure, not a silent hole.
  #
  # One callback rather than Pundit's usual `only: :index` / `except: :index`
  # pair, because Rails 8 raises when an `only:` names an action a controller
  # does not define — and most controllers here do not have every action.
  after_action :verify_pundit_usage, unless: :pundit_exempt?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  # An index must scope its query; every other action must authorize its record.
  # A controller that legitimately does neither says so with Pundit's
  # `skip_authorization` / `skip_policy_scope`, which is greppable.
  def verify_pundit_usage
    action_name == "index" ? verify_policy_scoped : verify_authorized
  end

  # Devise's own controllers and public pages manage their own access rules.
  def pundit_exempt?
    devise_controller? || is_a?(Public::BaseController)
  end

  def pundit_user = Current.user

  def user_not_authorized
    respond_to do |format|
      format.html do
        redirect_back fallback_location: root_path,
                      alert: "You are not allowed to do that."
      end
      format.json { render json: { error: "forbidden" }, status: :forbidden }
      format.any  { head :forbidden }
    end
  end

  # A record belonging to another team is not forbidden, it does not exist for
  # this request. 404 is the honest answer and it leaks nothing.
  def record_not_found
    respond_to do |format|
      format.html { render "errors/not_found", status: :not_found, layout: "application" }
      format.json { render json: { error: "not_found" }, status: :not_found }
      format.any  { head :not_found }
    end
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[first_name last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[first_name last_name])
  end

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || root_path
  end
end
