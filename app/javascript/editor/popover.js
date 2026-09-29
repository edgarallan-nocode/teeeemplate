// A small floating panel anchored to a rectangle — the link editor, and the
// URL prompt an image or a video block opens with. Positioned `fixed`, so a
// viewport rectangle is enough and the page's scroll offset never enters into
// it; repositioned on scroll because the anchor moves with the page.
export class Popover {
  constructor({ className = "" } = {}) {
    this.element = document.createElement("div")
    this.element.className = `editor-popover ${className}`.trim()
    this.element.hidden = true
    this.element.setAttribute("role", "dialog")
    document.body.append(this.element)

    this.onDocumentMouseDown = this.onDocumentMouseDown.bind(this)
    this.onKeyDown = this.onKeyDown.bind(this)
  }

  open(rect) {
    this.rect = rect
    this.element.hidden = false
    this.position()
    document.addEventListener("mousedown", this.onDocumentMouseDown, true)
    this.element.addEventListener("keydown", this.onKeyDown)
  }

  close() {
    if (this.element.hidden) return
    this.element.hidden = true
    document.removeEventListener("mousedown", this.onDocumentMouseDown, true)
    this.element.removeEventListener("keydown", this.onKeyDown)
    this.onClose?.()
  }

  get isOpen() {
    return !this.element.hidden
  }

  destroy() {
    this.close()
    this.element.remove()
  }

  position() {
    if (!this.rect) return
    const { width, height } = this.element.getBoundingClientRect()
    const gap = 8
    let top = this.rect.bottom + gap
    if (top + height > window.innerHeight - gap) top = Math.max(gap, this.rect.top - height - gap)
    const left = Math.min(Math.max(gap, this.rect.left), window.innerWidth - width - gap)
    this.element.style.top = `${top}px`
    this.element.style.left = `${left}px`
  }

  onDocumentMouseDown(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  onKeyDown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.close()
    }
  }
}

// Where the caret or selection is, as a viewport rectangle, for anchoring.
export function selectionRect(editor) {
  const { from, to } = editor.state.selection
  const start = editor.view.coordsAtPos(from)
  const end = editor.view.coordsAtPos(to, -1)
  return {
    top: Math.min(start.top, end.top),
    bottom: Math.max(start.bottom, end.bottom),
    left: Math.min(start.left, end.left),
    right: Math.max(start.right, end.right)
  }
}
