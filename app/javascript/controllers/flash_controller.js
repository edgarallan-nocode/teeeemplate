import { Controller } from "@hotwired/stimulus"

// Dismissible flash messages that fade themselves out.
//
//   <div data-controller="flash" class="alert alert--notice">
//     <div class="alert__body">Saved.</div>
//     <button data-action="flash#dismiss">&times;</button>
//   </div>
//
// Errors stay put — a message telling you something went wrong should not
// disappear before you have read it.
export default class extends Controller {
  static values = {
    timeout: { type: Number, default: 5000 },
    dismissible: { type: Boolean, default: true }
  }

  connect() {
    if (!this.dismissibleValue || this.timeoutValue <= 0) return

    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss(event) {
    if (event) event.preventDefault()

    clearTimeout(this.timer)
    this.element.remove()
  }

  // Hovering pauses the countdown so a message cannot vanish mid-read.
  pause() {
    clearTimeout(this.timer)
  }

  resume() {
    if (!this.dismissibleValue) return

    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }
}
