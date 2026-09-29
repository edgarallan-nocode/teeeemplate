# frozen_string_literal: true

module Projects
  # Where the description editor posts a picture. JSON in, JSON out: the
  # response carries the address the editor writes into the text, served through
  # Active Storage's redirect route so the bucket's own URLs never appear in a
  # description.
  #
  # Through the team like every other lookup, so a picture cannot be hung off
  # another team's project — and `upload_image?` is asked, so only somebody who
  # may edit the project may put a picture in it.
  class ImagesController < ApplicationController
    before_action :set_project

    def create
      authorize @project, :upload_image?

      result = RichText::AttachImage.call(record: @project, upload: params[:image])

      if result.success?
        blob = result.value
        render json: { url: rails_blob_path(blob, only_path: true), alt: blob.filename.base }, status: :created
      else
        render json: { error: result.error }, status: :unprocessable_content
      end
    end

    private

    def set_project
      @project = current_team.projects.find(params[:project_id])
    end
  end
end
