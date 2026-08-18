# frozen_string_literal: true

module Teams
  class InviteMember < ApplicationService
    def initialize(team:, email:, role:, invited_by:)
      @team = team
      @email = email.to_s.strip.downcase
      @role = role
      @invited_by = invited_by
    end

    def call
      invitation = @team.invitations.build(
        email: @email, role: @role, invited_by: @invited_by
      )

      # A previous invitation to the same address may have expired. Reuse the
      # row so the partial unique index does not reject a legitimate re-invite.
      if (stale = expired_invitation)
        stale.assign_attributes(
          role: @role, invited_by: @invited_by,
          token: SecureRandom.urlsafe_base64(32),
          expires_at: TeamInvitation::EXPIRY.from_now
        )
        return deliver(stale) if stale.save

        return failure_from(stale)
      end

      return failure_from(invitation) unless invitation.save

      deliver(invitation)
    end

    private

    def expired_invitation
      @team.invitations.expired.find_by(email: @email)
    end

    def deliver(invitation)
      TeamMailer.invitation(invitation).deliver_later
      success(invitation)
    end
  end
end
