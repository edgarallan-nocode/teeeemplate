# frozen_string_literal: true

# The pictures dropped into a record's rich text.
#
# Include it on the record the rich text field belongs to. Project is the worked
# example: a picture dropped into a project's description lands here the moment
# it is dropped — before the form is even submitted — so the record has to be one
# that already exists and that the person may write to. See
# Projects::ImagesController and RichText::AttachImage.
#
# Three formats, a size cap, Active Storage underneath: S3 in production through
# the instance role, disk in development and test.
module EditorImages
  extend ActiveSupport::Concern

  CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  MAX_BYTES = 10.megabytes

  included do
    has_many_attached :images
  end

  # Whether a blob may join the collection, in words for the person who dropped
  # it. Nil when it may.
  def image_refusal(blob)
    return "must be a PNG, JPEG or WEBP image" unless blob.content_type.in?(CONTENT_TYPES)
    return "must be smaller than #{MAX_BYTES / 1.megabyte}MB" if blob.byte_size > MAX_BYTES

    nil
  end
end
