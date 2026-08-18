# frozen_string_literal: true

require "rails_helper"

RSpec.describe Admin::StartImpersonation do
  let(:platform_admin) { create(:user, :admin) }
  let(:target) { create(:user) }

  it "closes any session the admin left open, so the audit trail cannot overlap" do
    stale = create(:impersonation_event, admin: platform_admin, user: create(:user))

    described_class.call(admin: platform_admin, user: target)

    expect(stale.reload).not_to be_active
    expect(ImpersonationEvent.open.count).to eq(1)
  end

  it "refuses a non-admin caller even though the controller already checked" do
    result = described_class.call(admin: create(:user), user: target)

    expect(result).to be_failure
    expect(ImpersonationEvent.count).to eq(0)
  end

  it "refuses an admin target" do
    result = described_class.call(admin: platform_admin, user: create(:user, :admin))

    expect(result).to be_failure
  end
end
