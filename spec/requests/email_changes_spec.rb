# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Email changes" do
  # :confirmable is gone, so changing an address is not verified. This
  # notification is the compensating control: the *previous* address is told,
  # which is the only signal a hijacked account gives its real owner. If it
  # stops firing, that mitigation is gone silently.
  let(:user) { create(:user, :with_team, email: "original@example.com") }

  before { sign_in user }

  it "notifies the previous address when the email changes" do
    expect(Devise.send_email_changed_notification).to be(true)

    perform_enqueued_jobs do
      user.update!(email: "changed@example.com")
    end

    notice = ActionMailer::Base.deliveries.last
    expect(notice).to be_present
    expect(notice.to).to eq([ "original@example.com" ])
    expect(notice.subject).to match(/email/i)
  end

  it "takes effect immediately, with no verification step" do
    user.update!(email: "changed@example.com")

    expect(user.reload.email).to eq("changed@example.com")

    # The new address works for signing in straight away.
    sign_out user
    post user_session_path,
         params: { user: { email: "changed@example.com", password: "password1234" } }

    expect(response).to redirect_to(root_path)
  end
end
