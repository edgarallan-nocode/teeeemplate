# frozen_string_literal: true

# The isolation contract every tenant-scoped resource must satisfy.
#
# Two assertions matter here, and the second is the subtle one:
#
#   1. Another team's record is not reachable.
#   2. The response is 404, not 403. A 403 confirms the record exists, which
#      leaks the existence of other teams' data. Because every controller
#      starts its query from Current.team, the record genuinely is not found —
#      404 is the honest answer, and it is also the safe one.
#
# Usage:
#
#   it_behaves_like "a tenant-isolated resource" do
#     let(:factory) { :project }
#     let(:member_path) { ->(record) { project_path(record) } }
#     let(:collection_path) { projects_path }
#     let(:update_params) { { project: { name: "Hijacked" } } }
#   end
RSpec.shared_examples "a tenant-isolated resource" do
  let(:mine)   { create_tenant }
  let(:theirs) { create_tenant }
  let!(:my_record)    { create(factory, team: mine.team) }
  let!(:their_record) { create(factory, team: theirs.team) }

  before { sign_in mine.owner }

  it "returns 404 for another team's record, rather than 403" do
    get member_path.call(their_record)

    # 403 would confirm the record exists. It must be indistinguishable from
    # an id that was never issued.
    expect(response).not_to have_http_status(:forbidden)
    expect(response).to have_http_status(:not_found)
  end

  it "shows the user's own record" do
    get member_path.call(my_record)

    expect(response).to have_http_status(:ok)
  end

  it "never lists another team's records" do
    get collection_path

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(html(their_record.name)) if their_record.respond_to?(:name)
  end

  it "refuses to update another team's record" do
    patch member_path.call(their_record), params: update_params

    expect(response).to have_http_status(:not_found)
  end

  it "refuses to destroy another team's record" do
    expect { delete member_path.call(their_record) }
      .not_to change { their_record.class.exists?(their_record.id) }

    expect(response).to have_http_status(:not_found)
  end
end
