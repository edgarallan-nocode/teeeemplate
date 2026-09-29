import { icons } from "./icons"

// The floating panel that opens on `/`. Rendered by hand rather than by a
// positioning library: one panel, anchored to the rectangle the suggestion
// plugin reports, flipped above the caret when there is no room below.
//
// State is small: the groups to show, the flat list of rows in display order,
// which row is selected, and the parent item when a submenu is open. Every
// change re-renders the whole panel from that state.
export class SlashCommandMenu {
  constructor({ items, command, clientRect, query }) {
    this.command = command
    this.clientRect = clientRect
    this.query = query
    this.groups = items
    this.parent = null
    this.selectedIndex = 0

    this.element = document.createElement("div")
    this.element.className = "slash-menu"
    this.element.setAttribute("role", "listbox")
    this.element.setAttribute("aria-label", "Insert")
    // Mousedown, not click, and prevented: a click would move focus out of the
    // editor and end the suggestion before the item could run.
    this.element.addEventListener("mousedown", (event) => event.preventDefault())
    document.body.append(this.element)

    this.render()
  }

  update({ items, clientRect, query }) {
    // Typing more leaves a submenu: the letters now filter the top level again.
    if (query !== this.query) this.parent = null
    this.query = query
    this.groups = items
    this.clientRect = clientRect
    this.selectedIndex = 0
    this.render()
  }

  // The rows currently on screen, in order, so arrow keys can walk them.
  get rows() {
    if (this.parent) return this.parent.children
    return this.groups.flatMap((group) => group.items)
  }

  onKeyDown(event) {
    const rows = this.rows
    switch (event.key) {
      case "ArrowDown":
        this.move(1)
        return true
      case "ArrowUp":
        this.move(-1)
        return true
      case "ArrowRight":
        if (rows[this.selectedIndex]?.children) {
          this.enter(rows[this.selectedIndex])
          return true
        }
        return false
      case "ArrowLeft":
        if (this.parent) {
          this.leave()
          return true
        }
        return false
      case "Enter":
      case "Tab":
        if (rows.length === 0) return false
        this.select(rows[this.selectedIndex])
        return true
      default:
        return false
    }
  }

  move(delta) {
    const count = this.rows.length
    if (count === 0) return
    this.highlight((this.selectedIndex + delta + count) % count)
    this.element.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: "nearest" })
  }

  highlight(index) {
    this.selectedIndex = index
    this.element.querySelectorAll('[role="option"]').forEach((row, rowIndex) => {
      row.setAttribute("aria-selected", String(rowIndex === index))
    })
  }

  select(item) {
    if (item.children) this.enter(item)
    else this.command(item)
  }

  enter(item) {
    this.parent = item
    this.selectedIndex = 0
    this.render()
  }

  leave() {
    this.parent = null
    this.selectedIndex = 0
    this.render()
  }

  destroy() {
    this.element.remove()
  }

  // --- Rendering -------------------------------------------------------------

  render() {
    this.element.replaceChildren()

    if (this.parent) {
      this.element.append(this.backRow(), this.label(this.parent.label))
      this.parent.children.forEach((item, index) => this.element.append(this.row(item, index)))
    } else if (this.rows.length === 0) {
      const empty = document.createElement("p")
      empty.className = "slash-menu__empty"
      empty.textContent = "No matches"
      this.element.append(empty)
    } else {
      let index = 0
      this.groups.forEach((group, groupIndex) => {
        if (groupIndex > 0) this.element.append(this.divider())
        this.element.append(this.label(group.label))
        group.items.forEach((item) => this.element.append(this.row(item, index++)))
      })
    }

    this.element.append(this.filterRow())
    this.position()
    this.element.querySelector('[aria-selected="true"]')?.scrollIntoView({ block: "nearest" })
  }

  label(text) {
    const element = document.createElement("p")
    element.className = "slash-menu__label"
    element.textContent = text
    return element
  }

  divider() {
    const element = document.createElement("hr")
    element.className = "slash-menu__divider"
    return element
  }

  row(item, index) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "slash-menu__item"
    button.setAttribute("role", "option")
    button.setAttribute("aria-selected", String(index === this.selectedIndex))
    button.dataset.label = item.label

    const icon = document.createElement("span")
    icon.className = "slash-menu__icon"
    icon.innerHTML = item.icon || ""

    const label = document.createElement("span")
    label.className = "slash-menu__text"
    label.textContent = item.label

    button.append(icon, label)

    if (item.children) {
      const chevron = document.createElement("span")
      chevron.className = "slash-menu__chevron"
      chevron.innerHTML = icons.chevronRight
      button.append(chevron)
    }

    // Highlight only — a full render here would replace the row under the
    // pointer between mousedown and click, and the click would land on nothing.
    button.addEventListener("mouseenter", () => this.highlight(index))
    button.addEventListener("click", () => this.select(item))

    return button
  }

  backRow() {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "slash-menu__item slash-menu__item--back"
    button.innerHTML = `<span class="slash-menu__icon">${icons.chevronLeft}</span><span class="slash-menu__text">Back</span>`
    button.addEventListener("click", () => this.leave())
    return button
  }

  // What is being typed, shown inside the panel so the filter is visible even
  // when the caret has scrolled out of view.
  filterRow() {
    const element = document.createElement("p")
    element.className = "slash-menu__filter"
    element.innerHTML = `<span class="slash-menu__slash">/</span>`
    const text = document.createElement("span")
    text.textContent = this.query || "Filter…"
    if (!this.query) text.className = "slash-menu__placeholder"
    element.append(text)
    return element
  }

  position() {
    const rect = this.clientRect?.()
    if (!rect) return
    const { width, height } = this.element.getBoundingClientRect()
    const gap = 6
    let top = rect.bottom + gap
    if (top + height > window.innerHeight - gap) top = Math.max(gap, rect.top - height - gap)
    const left = Math.min(Math.max(gap, rect.left), window.innerWidth - width - gap)
    this.element.style.top = `${top}px`
    this.element.style.left = `${left}px`
  }
}
