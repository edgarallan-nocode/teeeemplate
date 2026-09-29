import { icons } from "./icons"

// Row and column controls, shown on the toolbar while the caret is in a table.
export class TableControls {
  constructor(editor) {
    this.editor = editor
    this.element = document.createElement("div")
    this.element.className = "editor-toolbar__group"

    const buttons = [
      { title: "Add row below", icon: icons.rowAfter, run: () => editor.chain().focus().addRowAfter().run() },
      { title: "Add column after", icon: icons.columnAfter, run: () => editor.chain().focus().addColumnAfter().run() },
      { title: "Delete row", label: "Row", icon: icons.trash, run: () => editor.chain().focus().deleteRow().run() },
      { title: "Delete column", label: "Col", icon: icons.trash, run: () => editor.chain().focus().deleteColumn().run() },
      { title: "Delete table", label: "Table", icon: icons.trash, run: () => editor.chain().focus().deleteTable().run() }
    ]

    buttons.forEach(({ title, label, icon, run }) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "editor-toolbar__button"
      button.title = title
      button.setAttribute("aria-label", title)
      button.innerHTML = label ? `${icon}<span class="editor-toolbar__caption">${label}</span>` : icon
      button.addEventListener("click", run)
      this.element.append(button)
    })
  }
}
