import { Controller } from "@hotwired/stimulus"

// Toggles a menu, and closes it on outside click or Escape.
//
//   <div data-controller="dropdown">
//     <button data-action="dropdown#toggle" data-dropdown-target="button">Menu</button>
//     <div data-dropdown-target="menu" hidden>…</div>
//   </div>
export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
  }

  disconnect() {
    this.stopListening()
  }

  toggle(event) {
    event.preventDefault()
    this.isOpen ? this.close() : this.open()
  }

  open() {
    this.menuTarget.hidden = false
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "true")

    // Deferred so the click that opened the menu does not immediately close it.
    requestAnimationFrame(() => {
      document.addEventListener("click", this.closeOnOutsideClick)
      document.addEventListener("keydown", this.closeOnEscape)
    })
  }

  close() {
    this.menuTarget.hidden = true
    if (this.hasButtonTarget) this.buttonTarget.setAttribute("aria-expanded", "false")
    this.stopListening()
  }

  stopListening() {
    document.removeEventListener("click", this.closeOnOutsideClick)
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape(event) {
    if (event.key !== "Escape") return

    this.close()
    if (this.hasButtonTarget) this.buttonTarget.focus()
  }

  get isOpen() {
    return !this.menuTarget.hidden
  }
}
