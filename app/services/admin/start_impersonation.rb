# frozen_string_literal: true

module Admin
  # Begins a support impersonation session and records it.
  #
  # The authorization decision lives in Admin::UserPolicy#impersonate?; this
  # service enforces the invariants that must hold regardless of who calls it.
  class StartImpersonation < ApplicationService
    def initialize(admin:, user:, ip_address: nil, user_agent: nil, reason: nil)
      @admin = admin
      @user = user
      @ip_address = ip_address
      @user_agent = user_agent
      @reason = reason
    end

    def call
      return failure("Only platform administrators may impersonate.") unless @admin&.admin?
      return failure("Administrators cannot be impersonated.") if @user.admin?
      return failure("You cannot impersonate yourself.") if @user == @admin

      # Close anything left open so an admin never has two live sessions and the
      # audit trail cannot show overlapping impersonations.
      ImpersonationEvent.open.where(admin: @admin).find_each(&:close!)

      event = ImpersonationEvent.create!(
        admin: @admin,
        user: @user,
        started_at: Time.current,
        ip_address: @ip_address,
        user_agent: @user_agent,
        reason: @reason
      )

      Rails.logger.info(
        "[impersonation] start admin=#{@admin.id} user=#{@user.id} event=#{event.id}"
      )

      success(event)
    end
  end
end
