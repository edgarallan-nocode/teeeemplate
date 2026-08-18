import { Controller } from "@hotwired/stimulus"

// Client-side tabs. Use these only when all panels are cheap to render at once;
// otherwise use real links and let Turbo Drive load each view.
//
//   <div data-controller="tabs" data-tabs-active-value="details">
//     <button data-tabs-target="tab" data-tab="details" data-action="tabs#select">Details</button>
//     <section data-tabs-target="panel" data-tab="details">…</section>
//   </div>
export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { active: String }

  connect() {
    if (!this.activeValue && this.hasTabTarget) {
      this.activeValue = this.tabTargets[0].dataset.tab
    }
    this.render()
  }

  select(event) {
    event.preventDefault()
    this.activeValue = event.currentTarget.dataset.tab
  }

  activeValueChanged() {
    this.render()
  }

  render() {
    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.tab === this.activeValue
      tab.setAttribute("aria-selected", selected ? "true" : "false")
      tab.tabIndex = selected ? 0 : -1
    })

    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.tab !== this.activeValue
    })
  }
}
