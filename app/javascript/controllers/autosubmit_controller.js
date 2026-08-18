import { Controller } from "@hotwired/stimulus"

// Submits a form as the user types or changes a control — search boxes and
// filter dropdowns.
//
//   <form data-controller="autosubmit" data-action="input->autosubmit#submit">
//
// Text input is debounced; selects and checkboxes submit immediately, since
// there is nothing to wait for.
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  submit(event) {
    const immediate =
      event?.target?.tagName === "SELECT" ||
      ["checkbox", "radio"].includes(event?.target?.type)

    clearTimeout(this.timeout)

    if (immediate) {
      this.perform()
    } else {
      this.timeout = setTimeout(() => this.perform(), this.delayValue)
    }
  }

  perform() {
    this.element.requestSubmit()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
