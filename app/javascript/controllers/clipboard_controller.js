import { Controller } from "@hotwired/stimulus"

// Copy-to-clipboard with visible confirmation.
//
//   <div data-controller="clipboard" data-clipboard-text-value="…">
//     <button data-action="clipboard#copy" data-clipboard-target="button">Copy</button>
//   </div>
//
// Falls back to the source element's value/text when no text value is given.
export default class extends Controller {
  static targets = ["source", "button"]
  static values = { text: String, successMessage: { type: String, default: "Copied" } }

  async copy(event) {
    event.preventDefault()

    try {
      await navigator.clipboard.writeText(this.textToCopy)
      this.confirm()
    } catch {
      // Clipboard access can be denied; selecting the text is a usable fallback.
      if (this.hasSourceTarget && this.sourceTarget.select) this.sourceTarget.select()
    }
  }

  confirm() {
    if (!this.hasButtonTarget) return

    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.successMessageValue
    this.buttonTarget.disabled = true

    clearTimeout(this.resetTimer)
    this.resetTimer = setTimeout(() => {
      this.buttonTarget.textContent = original
      this.buttonTarget.disabled = false
    }, 1500)
  }

  disconnect() {
    clearTimeout(this.resetTimer)
  }

  get textToCopy() {
    if (this.hasTextValue) return this.textValue
    if (!this.hasSourceTarget) return ""

    return this.sourceTarget.value ?? this.sourceTarget.textContent.trim()
  }
}
