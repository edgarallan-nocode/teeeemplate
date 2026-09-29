// Posts a picture to the project's images endpoint and returns the address the
// server stored it at. One request per file, through the application rather
// than straight to the bucket, the same path the card icons take.
//
// Errors are reported through `onStatus` in words the server wrote — "must be
// a PNG, JPEG or WEBP image" — and never thrown at the caller, which has
// nothing useful to do with an exception mid-drop.
export class ImageUploader {
  constructor({ url, onStatus }) {
    this.url = url
    this.onStatus = onStatus || (() => {})
  }

  async upload(file) {
    if (!this.url) {
      this.onStatus("This editor cannot upload pictures.", true)
      return null
    }

    this.onStatus(`Uploading ${file.name}…`)

    const body = new FormData()
    body.append("image", file, file.name)

    try {
      const response = await fetch(this.url, {
        method: "POST",
        body,
        credentials: "same-origin",
        headers: { "X-CSRF-Token": csrfToken(), Accept: "application/json" }
      })
      const payload = await response.json().catch(() => ({}))

      if (!response.ok) {
        this.onStatus(payload.error || `The upload failed (${response.status}).`, true)
        return null
      }

      this.onStatus(null)
      return payload
    } catch {
      this.onStatus("The upload failed. Check the connection and try again.", true)
      return null
    }
  }
}

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || ""
}
