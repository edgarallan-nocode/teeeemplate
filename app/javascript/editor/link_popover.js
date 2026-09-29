import { Popover, selectionRect } from "./popover"

// Setting and clearing a link on the current selection. Opened from the
// toolbar's link button and from Cmd/Ctrl+K.
//
// A bare domain gets `https://` in front of it — people paste `example.com`
// far more often than they type a scheme — but nothing else is guessed, and
// the server sanitises the href again before it is stored or rendered.
export class LinkPopover extends Popover {
  constructor(editor) {
    super({ className: "editor-popover--link" })
    this.editor = editor
    this.build()
  }

  build() {
    this.form = document.createElement("form")
    this.form.className = "editor-popover__form"

    this.input = document.createElement("input")
    this.input.type = "url"
    this.input.className = "input"
    this.input.placeholder = "https://…"
    this.input.setAttribute("aria-label", "Link address")

    const apply = document.createElement("button")
    apply.type = "submit"
    apply.className = "btn btn--primary btn--sm"
    apply.textContent = "Apply"

    this.remove = document.createElement("button")
    this.remove.type = "button"
    this.remove.className = "btn btn--ghost btn--sm"
    this.remove.textContent = "Remove"
    this.remove.addEventListener("click", () => {
      this.editor.chain().focus().extendMarkRange("link").unsetLink().run()
      this.close()
    })

    this.form.append(this.input, apply, this.remove)
    this.form.addEventListener("submit", (event) => {
      event.preventDefault()
      this.apply()
    })
    this.element.append(this.form)
  }

  open() {
    if (this.editor.state.selection.empty && !this.editor.isActive("link")) return

    const current = this.editor.getAttributes("link").href || ""
    this.input.value = current
    this.remove.hidden = !current
    super.open(selectionRect(this.editor))
    this.input.focus()
    this.input.select()
  }

  apply() {
    const href = normalise(this.input.value)
    const chain = this.editor.chain().focus().extendMarkRange("link")
    if (href) chain.setLink({ href }).run()
    else chain.unsetLink().run()
    this.close()
  }
}

function normalise(value) {
  const trimmed = value.trim()
  if (!trimmed) return ""
  if (/^(https?:\/\/|mailto:)/i.test(trimmed)) return trimmed
  return `https://${trimmed}`
}
