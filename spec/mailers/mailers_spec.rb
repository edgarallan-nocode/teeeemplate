# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Mailers" do
  # Every template must render in both formats. A plain-text part is not
  # optional — some clients only show that one, and its absence hurts
  # deliverability.
  shared_examples "an email with both formats" do
    it "renders an HTML part and a plain-text part" do
      expect(mail.body.parts.map { _1.content_type.split(";").first })
        .to include("text/html", "text/plain")
    end

    it "has a subject and a recipient" do
      expect(mail.subject).to be_present
      expect(mail.to).to be_present
    end

    it "sends from the configured address" do
      expect(mail.from).to eq([ Rails.configuration.x.mailer_from ])
    end
  end

  describe TeamMailer do
    describe "invitation" do
      let(:invitation) { create(:team_invitation, email: "invitee@example.com") }
      let(:mail) { described_class.invitation(invitation) }

      it_behaves_like "an email with both formats"

      it "addresses the invitee and links to the accept page" do
        expect(mail.to).to eq([ "invitee@example.com" ])
        expect(mail.body.encoded).to include(invitation.token)
      end

      it "names the team and the inviter in the subject" do
        expect(mail.subject).to include(invitation.team.name)
        expect(mail.subject).to include(invitation.invited_by.name)
      end
    end

    describe "member_removed" do
      let(:team) { create(:team) }
      let(:user) { create(:user) }
      let(:mail) { described_class.member_removed(user, team) }

      it_behaves_like "an email with both formats"
    end
  end

  describe BillingMailer do
    let(:team) { create(:team) }

    before do
      create(:membership, :owner, user: create(:user, email: "owner@example.com"), team: team)
      create(:membership, :member, team: team)
      create(:subscription, team: team, status: "past_due")
    end

    describe "payment_failed" do
      let(:mail) { described_class.payment_failed(team.reload) }

      it_behaves_like "an email with both formats"

      it "goes to the team's owners, not to ordinary members" do
        # Billing belongs to the team, so billing mail goes to whoever can act
        # on it — not to whoever happened to trigger the event.
        expect(mail.to).to eq([ "owner@example.com" ])
      end
    end

    describe "subscription_canceled" do
      let(:mail) { described_class.subscription_canceled(team.reload) }

      it_behaves_like "an email with both formats"
    end
  end

  describe Users::DeviseMailer do
    let(:user) { create(:user) }

    describe "email_changed" do
      let(:mail) { described_class.email_changed(user) }

      it_behaves_like "an email with both formats"

      it "warns the address that the account's email was changed" do
        # Addresses are not verified, so this notice is the only signal a
        # hijacked account gives its real owner.
        expect(mail.body.encoded).to include(user.email)
      end
    end

    describe "reset_password_instructions" do
      let(:mail) { described_class.reset_password_instructions(user, "reset-token") }

      it_behaves_like "an email with both formats"

      it "includes the reset token" do
        expect(mail.body.encoded).to include("reset-token")
      end
    end
  end

  describe "delivery" do
    it "always goes through Active Job, never inline" do
      user = create(:user)

      expect { user.send_reset_password_instructions }
        .to have_enqueued_job(ActionMailer::MailDeliveryJob)

      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end
end
