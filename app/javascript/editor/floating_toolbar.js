import { icons } from "./icons"
import { HeadingDropdown } from "./heading_dropdown"
import { TableControls } from "./table_controls"
import { selectionRect } from "./popover"

const LANGUAGES = ["", "bash", "css", "html", "javascript", "json", "python", "ruby", "sql", "typescript", "yaml"]

// The contextual toolbar. It appears above a text selection with the block-type
// dropdown and the inline marks, shows row and column controls whenever the
// caret is inside a table, and shows a language picker inside a code block. It
// hides when the selection collapses or the editor loses focus to anything
// that is not one of its own panels.
export class FloatingToolbar {
  constructor(editor, { onLink }) {
    this.editor = editor
    this.onLink = onLink

    this.element = document.createElement("div")
    this.element.className = "editor-toolbar"
    this.element.setAttribute("role", "toolbar")
    this.element.setAttribute("aria-label", "Formatting")
    this.element.hidden = true
    // Buttons take focus on mousedown; preventing it keeps the selection in the
    // editor so the command has something to act on.
    this.element.addEventListener("mousedown", (event) => {
      if (event.target.closest("select, input")) return
      event.preventDefault()
    })
    document.body.append(this.element)

    this.build()

    this.refresh = this.refresh.bind(this)
    this.editor.on("selectionUpdate", this.refresh)
    this.editor.on("transaction", this.refresh)
    this.editor.on("blur", this.refresh)
    this.editor.on("focus", this.refresh)
    window.addEventListener("scroll", this.refresh, true)
    window.addEventListener("resize", this.refresh)
  }

  build() {
    this.heading = new HeadingDropdown(this.editor)

    this.marks = document.createElement("div")
    this.marks.className = "editor-toolbar__group"
    this.buttons = [
      { name: "link", title: "Link (⌘K)", icon: icons.link, run: () => this.onLink() },
      { name: "bold", title: "Bold (⌘B)", icon: icons.bold, run: () => this.editor.chain().focus().toggleBold().run() },
      { name: "italic", title: "Italic (⌘I)", icon: icons.italic, run: () => this.editor.chain().focus().toggleItalic().run() },
      { name: "blockquote", title: "Blockquote", icon: icons.blockquote, run: () => this.editor.chain().focus().toggleBlockquote().run() },
      { name: "code", title: "Inline code", icon: icons.code, run: () => this.editor.chain().focus().toggleCode().run() }
    ].map((spec) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "editor-toolbar__button"
      button.title = spec.title
      button.setAttribute("aria-label", spec.title)
      button.dataset.mark = spec.name
      button.innerHTML = spec.icon
      button.addEventListener("click", spec.run)
      this.marks.append(button)
      return { ...spec, button }
    })

    this.table = new TableControls(this.editor)

    this.language = document.createElement("select")
    this.language.className = "editor-toolbar__language"
    this.language.setAttribute("aria-label", "Code language")
    LANGUAGES.forEach((language) => {
      const option = document.createElement("option")
      option.value = language
      option.textContent = language || "Plain text"
      this.language.append(option)
    })
    this.language.addEventListener("change", () => {
      this.editor.chain().focus().updateAttributes("codeBlock", { language: this.language.value || null }).run()
    })

    this.element.append(this.heading.element, this.divider(), this.marks, this.divider(), this.table.element, this.language)
  }

  divider() {
    const element = document.createElement("span")
    element.className = "editor-toolbar__divider"
    element.setAttribute("aria-hidden", "true")
    return element
  }

  refresh() {
    const { editor } = this
    if (editor.isDestroyed) return

    const { empty } = editor.state.selection
    const inTable = editor.isActive("table")
    const inCode = editor.isActive("codeBlock")
    const focused = editor.isFocused || this.element.contains(document.activeElement) || this.heading.isOpen

    const showMarks = !empty && !inCode
    const visible = focused && (showMarks || inTable || (inCode && !empty))

    if (!visible) {
      this.element.hidden = true
      this.heading.close()
      return
    }

    this.heading.element.hidden = !showMarks
    this.marks.hidden = !showMarks
    this.table.element.hidden = !inTable
    this.language.hidden = !inCode
    this.element.querySelectorAll(".editor-toolbar__divider").forEach((divider, index) => {
      divider.hidden = index === 0 ? !showMarks : !(showMarks && inTable)
    })

    if (showMarks) {
      this.heading.refresh()
      this.buttons.forEach(({ name, button }) => {
        button.setAttribute("aria-pressed", String(editor.isActive(name)))
      })
    }
    if (inCode) this.language.value = editor.getAttributes("codeBlock").language || ""

    this.element.hidden = false
    this.position()
  }

  position() {
    const rect = selectionRect(this.editor)
    const { width, height } = this.element.getBoundingClientRect()
    const gap = 8
    let top = rect.top - height - gap
    if (top < gap) top = rect.bottom + gap
    const centre = (rect.left + rect.right) / 2
    const left = Math.min(Math.max(gap, centre - width / 2), window.innerWidth - width - gap)
    this.element.style.top = `${top}px`
    this.element.style.left = `${left}px`
  }

  destroy() {
    this.editor.off("selectionUpdate", this.refresh)
    this.editor.off("transaction", this.refresh)
    this.editor.off("blur", this.refresh)
    this.editor.off("focus", this.refresh)
    window.removeEventListener("scroll", this.refresh, true)
    window.removeEventListener("resize", this.refresh)
    this.heading.close()
    this.element.remove()
  }
}
