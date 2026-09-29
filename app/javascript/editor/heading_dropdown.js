import { icons } from "./icons"

// The block-type control on the toolbar: a button naming the current block and
// a menu of the four it can become. Closes on choice, on Escape, and on a click
// anywhere else.
const OPTIONS = [
  { label: "Paragraph", icon: icons.paragraph, isActive: (editor) => editor.isActive("paragraph"), run: (editor) => editor.chain().focus().setParagraph().run() },
  ...[1, 2, 3].map((level) => ({
    label: `Heading ${level}`,
    icon: icons[`h${level}`],
    isActive: (editor) => editor.isActive("heading", { level }),
    run: (editor) => editor.chain().focus().toggleHeading({ level }).run()
  }))
]

export class HeadingDropdown {
  constructor(editor) {
    this.editor = editor
    this.element = document.createElement("div")
    this.element.className = "editor-toolbar__group editor-dropdown"

    this.trigger = document.createElement("button")
    this.trigger.type = "button"
    this.trigger.className = "editor-toolbar__select"
    this.trigger.setAttribute("aria-haspopup", "listbox")
    this.trigger.setAttribute("aria-expanded", "false")
    this.trigger.addEventListener("click", () => this.toggle())

    this.menu = document.createElement("div")
    this.menu.className = "editor-menu"
    this.menu.setAttribute("role", "listbox")
    this.menu.hidden = true

    OPTIONS.forEach((option) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className = "editor-menu__item"
      item.setAttribute("role", "option")
      item.innerHTML = `<span class="editor-menu__icon">${option.icon}</span><span>${option.label}</span><span class="editor-menu__check">${icons.check}</span>`
      item.addEventListener("click", () => {
        option.run(this.editor)
        this.close()
      })
      item.dataset.label = option.label
      this.menu.append(item)
    })

    this.element.append(this.trigger, this.menu)
    this.onDocumentMouseDown = (event) => {
      if (!this.element.contains(event.target)) this.close()
    }
  }

  refresh() {
    const current = OPTIONS.find((option) => option.isActive(this.editor)) || OPTIONS[0]
    this.trigger.innerHTML = `<span>${current.label}</span>${icons.chevronDown}`
    this.menu.querySelectorAll(".editor-menu__item").forEach((item) => {
      item.setAttribute("aria-selected", String(item.dataset.label === current.label))
    })
  }

  toggle() {
    this.menu.hidden ? this.open() : this.close()
  }

  open() {
    this.refresh()
    this.menu.hidden = false
    this.trigger.setAttribute("aria-expanded", "true")
    document.addEventListener("mousedown", this.onDocumentMouseDown, true)
  }

  close() {
    this.menu.hidden = true
    this.trigger.setAttribute("aria-expanded", "false")
    document.removeEventListener("mousedown", this.onDocumentMouseDown, true)
  }

  get isOpen() {
    return !this.menu.hidden
  }
}
