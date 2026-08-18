# frozen_string_literal: true

module Teams
  # Turns a pending invitation into a membership.
  #
  # Written to be safe against a double-click or a re-opened email: if the user
  # is already a member, it succeeds quietly rather than raising.
  class AcceptInvitation < ApplicationService
    def initialize(invitation:, user:)
      @invitation = invitation
      @user = user
    end

    def call
      refusal = refusal_reason
      return failure(refusal) if refusal

      success(accept!)
    rescue ActiveRecord::RecordInvalid => e
      failure(e.record.errors.full_messages.to_sentence)
    end

    private

    def refusal_reason
      return "This invitation has already been accepted." if @invitation.accepted?
      return "This invitation has expired." if @invitation.expired?
      return "This invitation was sent to a different email address." unless addressed_to_user?

      nil
    end

    def addressed_to_user? = @invitation.email == @user.email

    def accept!
      membership = nil

      ActiveRecord::Base.transaction do
        membership = @user.memberships.find_or_initialize_by(team: @invitation.team)
        membership.role = @invitation.role if membership.new_record?
        membership.save!

        @invitation.update!(accepted_at: Time.current, accepted_by: @user)
        @user.update_column(:last_team_id, @invitation.team_id)
      end

      membership
    end
  end
end
