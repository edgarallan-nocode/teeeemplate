# frozen_string_literal: true

module Teams
  class ChangeRole < ApplicationService
    def initialize(membership:, role:)
      @membership = membership
      @role = role.to_s
    end

    def call
      return failure("#{@role.inspect} is not a valid role.") unless valid_role?
      return success(@membership) if @membership.role == @role

      @membership.role = @role

      # The last-owner invariant lives on the model, so it applies here and to
      # any other caller without being restated.
      return failure_from(@membership) unless @membership.save

      success(@membership)
    end

    private

    def valid_role? = Membership.roles.key?(@role)
  end
end
