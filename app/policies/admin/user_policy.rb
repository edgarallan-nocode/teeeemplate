# frozen_string_literal: true

module Admin
  class UserPolicy < BasePolicy
    # An admin may never be impersonated. Without this, anyone who compromises
    # one staff account could quietly assume every other staff account, and the
    # audit trail would name the wrong person.
    def impersonate?
      return false unless platform_admin?
      return false if record.admin?
      return false if record == user

      true
    end
  end
end
