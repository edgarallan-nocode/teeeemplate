import { Controller } from "@hotwired/stimulus"

// A modal whose contents arrive in a Turbo Frame.
//
//   <div data-controller="modal" data-modal-target="container" hidden>
//     <div class="modal__panel" data-action="click->modal#stopPropagation">
//       <turbo-frame id="modal_content"></turbo-frame>
//     </div>
//   </div>
//
// Opening is a normal link targeting the frame; this controller only handles
// showing, hiding, focus and body scroll.
export default class extends Controller {
  static targets = ["container", "content"]

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("keydown", this.closeOnEscape)

    // Turbo replaces frame contents without a page load, so the modal has to
    // open in response to the frame rendering rather than to a click.
    this.element.addEventListener("turbo:frame-load", () => this.open())
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    this.unlockScroll()
  }

  open() {
    if (this.hasContentTarget && this.contentTarget.innerHTML.trim() === "") return

    this.containerTarget.hidden = false
    this.lockScroll()
    this.focusFirstElement()
  }

  close(event) {
    if (event) event.preventDefault()

    this.containerTarget.hidden = true
    this.unlockScroll()

    // Empty the frame so reopening the same URL fetches fresh content instead
    // of showing a stale form.
    if (this.hasContentTarget) this.contentTarget.innerHTML = ""
  }

  // Clicking the backdrop closes; clicking the panel must not.
  stopPropagation(event) {
    event.stopPropagation()
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && !this.containerTarget.hidden) this.close()
  }

  focusFirstElement() {
    const focusable = this.containerTarget.querySelector(
      "input:not([type=hidden]), textarea, select, button, [href]"
    )
    if (focusable) focusable.focus()
  }

  lockScroll() {
    document.body.style.overflow = "hidden"
  }

  unlockScroll() {
    document.body.style.overflow = ""
  }
}
