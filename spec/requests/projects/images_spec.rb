# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Project images" do
  let(:tenant) { create_tenant }
  let(:project) { create(:project, team: tenant.team) }
  let(:picture) { fixture_file_upload("logo.png", "image/png") }

  it "stores a member's picture with the project and answers with its address" do
    sign_in_as(tenant.member, team: tenant.team)

    post project_images_path(project), params: { image: picture }

    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body["url"]).to start_with("/rails/active_storage/")
    expect(body["alt"]).to eq("logo")
    expect(project.images.count).to eq(1)
  end

  it "refuses a file that is not a picture, in words, and keeps nothing" do
    sign_in_as(tenant.member, team: tenant.team)

    post project_images_path(project), params: { image: fixture_file_upload("not-an-image.txt", "text/plain") }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to include("PNG, JPEG or WEBP")
    expect(project.images.count).to eq(0)
  end

  # The content type is read from the bytes after upload, not from the request,
  # so relabelling a text file does not get it through.
  it "is not fooled by a claimed content type" do
    sign_in_as(tenant.member, team: tenant.team)

    post project_images_path(project), params: { image: fixture_file_upload("not-an-image.txt", "image/png") }

    expect(response).to have_http_status(:unprocessable_content)
    expect(project.images.count).to eq(0)
  end

  it "refuses a request with no file" do
    sign_in_as(tenant.member, team: tenant.team)

    post project_images_path(project)

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns 404 for another team's project, rather than 403" do
    theirs = create(:project, team: create_tenant.team)
    sign_in tenant.owner

    post project_images_path(theirs), params: { image: picture }

    expect(response).not_to have_http_status(:forbidden)
    expect(response).to have_http_status(:not_found)
    expect(theirs.images.count).to eq(0)
  end
end
