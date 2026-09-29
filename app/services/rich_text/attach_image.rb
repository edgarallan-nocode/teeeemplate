# frozen_string_literal: true

module RichText
  # Stores a picture for a record's rich text and answers with the blob.
  #
  # Two steps, which is why this is a service rather than a line in the
  # controller: the bytes are uploaded to storage first, so the content type
  # comes from the file itself rather than from what the browser claimed, and
  # only then is the blob checked and attached. A refused blob is purged on the
  # spot rather than left orphaned in the bucket.
  class AttachImage < ApplicationService
    def initialize(record:, upload:)
      @record = record
      @upload = upload
    end

    def call
      return failure("Choose a picture to upload.") unless @upload.respond_to?(:tempfile)

      # The browser's claimed content type is deliberately not passed: when the
      # bytes carry no signature, identification would fall back to the claim,
      # and a text file labelled image/png would get through. From the bytes
      # and the filename only.
      blob = ActiveStorage::Blob.create_and_upload!(
        io: @upload.tempfile,
        filename: @upload.original_filename,
        identify: true
      )

      if (reason = @record.image_refusal(blob))
        blob.purge_later
        return failure("The picture #{reason}.")
      end

      @record.images.attach(blob)
      success(blob)
    end
  end
end
