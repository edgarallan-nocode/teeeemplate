import { Popover, selectionRect } from "./popover"

// A one-shot prompt for a block that needs an address before it can exist —
// an image, a video. One or two fields, a submit, and a callback with the
// values. Opened where the slash command was typed.
export class BlockPrompt extends Popover {
  constructor(editor, { title, fields, submit, onSubmit, validate, file = null }) {
    super({ className: "editor-popover--block" })
    this.editor = editor
    this.onSubmit = onSubmit
    this.validate = validate
    this.build(title, fields, submit, file)
  }

  build(title, fields, submit, file) {
    const heading = document.createElement("p")
    heading.className = "editor-popover__title"
    heading.textContent = title

    this.form = document.createElement("form")
    this.form.className = "editor-popover__form editor-popover__form--stacked"

    // An optional file picker above the fields. Choosing a file is the whole
    // action: the prompt closes and hands the file on.
    if (file) {
      this.fileInput = document.createElement("input")
      this.fileInput.type = "file"
      this.fileInput.accept = file.accept || "image/*"
      this.fileInput.className = "input file-input"
      this.fileInput.setAttribute("aria-label", file.label)
      this.fileInput.addEventListener("change", () => {
        const chosen = this.fileInput.files?.[0]
        if (!chosen) return
        this.close()
        file.onFile(chosen)
      })
      this.form.append(this.fileInput)
    }

    this.inputs = fields.map((field) => {
      const input = document.createElement("input")
      input.type = field.type || "text"
      input.name = field.name
      input.className = "input"
      input.placeholder = field.placeholder || ""
      input.required = Boolean(field.required)
      input.setAttribute("aria-label", field.label)
      this.form.append(input)
      return input
    })

    this.error = document.createElement("p")
    this.error.className = "editor-popover__error"
    this.error.hidden = true

    const button = document.createElement("button")
    button.type = "submit"
    button.className = "btn btn--primary btn--sm"
    button.textContent = submit

    this.form.append(this.error, button)
    this.form.addEventListener("submit", (event) => {
      event.preventDefault()
      this.submit()
    })
    this.element.append(heading, this.form)
  }

  open() {
    this.inputs.forEach((input) => (input.value = ""))
    if (this.fileInput) this.fileInput.value = ""
    this.error.hidden = true
    super.open(selectionRect(this.editor))
    ;(this.fileInput || this.inputs[0]).focus()
  }

  submit() {
    const values = Object.fromEntries(this.inputs.map((input) => [input.name, input.value.trim()]))
    const problem = this.validate?.(values)
    if (problem) {
      this.error.textContent = problem
      this.error.hidden = false
      return
    }
    this.close()
    this.onSubmit(values)
  }
}
