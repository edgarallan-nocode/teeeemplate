# frozen_string_literal: true

module Admin
  class StopImpersonation < ApplicationService
    def initialize(event_id: nil, admin: nil)
      @event_id = event_id
      @admin = admin
    end

    def call
      event = find_event
      return success(nil) if event.nil?

      event.close!

      Rails.logger.info(
        "[impersonation] stop admin=#{event.admin_id} user=#{event.user_id} event=#{event.id}"
      )

      success(event)
    end

    private

    # Falls back to closing any open session for the admin, so a lost session
    # key cannot leave a dangling audit record.
    def find_event
      return ImpersonationEvent.find_by(id: @event_id) if @event_id.present?
      return ImpersonationEvent.open.find_by(admin: @admin) if @admin

      nil
    end
  end
end
