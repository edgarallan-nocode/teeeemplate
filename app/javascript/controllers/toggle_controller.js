import { Controller } from "@hotwired/stimulus"

// Shows and hides an element. The generic one — mobile menus, "show advanced
// options", inline detail panels.
//
//   <div data-controller="toggle">
//     <button data-action="toggle#toggle" data-toggle-target="trigger">Menu</button>
//     <nav data-toggle-target="content" hidden>…</nav>
//   </div>
export default class extends Controller {
  static targets = ["content", "trigger"]
  static classes = ["active"]

  toggle(event) {
    if (event) event.preventDefault()

    const willShow = this.contentTarget.hidden
    this.contentTarget.hidden = !willShow

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", willShow ? "true" : "false")
    }

    if (this.hasActiveClass) {
      this.element.classList.toggle(this.activeClass, willShow)
    }
  }

  show() {
    this.contentTarget.hidden = false
  }

  hide() {
    this.contentTarget.hidden = true
  }
}
