import { Controller } from "@hotwired/stimulus"
import { Editor } from "@tiptap/core"
import StarterKit from "@tiptap/starter-kit"
import Image from "@tiptap/extension-image"
import Youtube from "@tiptap/extension-youtube"
import { TableKit } from "@tiptap/extension-table"
import { Placeholder } from "@tiptap/extensions"
import { ImageUploader } from "../editor/image_uploader"
import { SlashCommands } from "../editor/slash_commands"
import { Shortcuts } from "../editor/shortcuts"
import { FloatingToolbar } from "../editor/floating_toolbar"
import { LinkPopover } from "../editor/link_popover"
import { ImageBlock } from "../editor/image_block"
import { YouTubeBlock } from "../editor/youtube_block"

// A rich text editor over two hidden fields.
//
//   <div data-controller="rich-text-editor"
//        data-rich-text-editor-placeholder-value="Write…"
//        data-rich-text-editor-upload-url-value="/projects/relaunch/images">
//     <input type="hidden" name="doc[body]"    data-rich-text-editor-target="html">
//     <input type="hidden" name="doc[content]" data-rich-text-editor-target="json">
//     <div class="editor" data-rich-text-editor-target="editor"></div>
//   </div>
//
// The fields are the form's truth. On every change the controller writes the
// editor's HTML to one and its JSON to the other, so the server receives both
// and the page can be reloaded into the editor exactly as it was left. With no
// JavaScript the fields still submit whatever was loaded into them.
//
// The editor opens from the JSON when there is any, otherwise from the HTML —
// which is what a document written through MCP has — so either column is enough
// to start from. TipTap (ProseMirror) is the one npm dependency here; the menus
// and toolbar around it are plain DOM in ../editor/, not a framework.
//
// Pictures are uploaded, not linked: a file dropped anywhere on the page, pasted,
// or chosen from the image prompt is posted to `uploadUrl` and the address that
// comes back is what goes in the text. See ../editor/image_uploader.js.
//
// Exposed for other scripts: `value`, `getHTML()`, `getJSON()`, `setContent()`,
// and a `rich-text-editor:change` event with both formats in `detail`.
export default class extends Controller {
  static targets = ["editor", "html", "json"]
  static values = {
    placeholder: { type: String, default: "Write, or type / for a block…" },
    uploadUrl: String
  }

  connect() {
    // Idempotent: Turbo can restore a page with the editor already drawn.
    this.teardown()

    this.linkPopover = null
    this.uploader = new ImageUploader({
      url: this.uploadUrlValue,
      onStatus: (message, failed) => this.showStatus(message, failed)
    })
    this.editor = new Editor({
      element: this.editorTarget,
      content: this.initialContent(),
      editorProps: {
        attributes: { class: "editor__content", role: "textbox", "aria-multiline": "true" },
        // A picture dropped or pasted into the text is uploaded and inserted where
        // it landed. Anything else is left to ProseMirror.
        handleDrop: (view, event, _slice, moved) => !moved && this.insertFiles(event.dataTransfer?.files, this.dropPosition(view, event)),
        handlePaste: (_view, event) => this.insertFiles(event.clipboardData?.files)
      },
      extensions: [
        StarterKit.configure({
          heading: { levels: [1, 2, 3] },
          link: { openOnClick: false, autolink: true, defaultProtocol: "https" }
        }),
        Placeholder.configure({ placeholder: this.placeholderValue }),
        Image.configure({ inline: false, allowBase64: false }),
        Youtube.configure({ nocookie: true, width: 640, height: 360 }),
        TableKit.configure({ table: { resizable: false } }),
        Shortcuts.configure({ onLink: () => this.linkPopover?.open() }),
        SlashCommands.configure({
          onImage: () => this.imageBlock.insert(),
          onYoutube: () => this.youtubeBlock.insert()
        })
      ],
      onUpdate: () => this.sync(),
      onCreate: () => this.sync()
    })

    this.linkPopover = new LinkPopover(this.editor)
    this.imageBlock = new ImageBlock(this.editor, { upload: (file) => this.insertFiles([file]) })
    this.youtubeBlock = new YouTubeBlock(this.editor)
    this.toolbar = new FloatingToolbar(this.editor, { onLink: () => this.linkPopover.open() })

    this.listenForPageDrops()
  }

  disconnect() {
    this.teardown()
  }

  teardown() {
    this.stopListeningForPageDrops()
    this.toolbar?.destroy()
    this.linkPopover?.destroy()
    this.imageBlock?.destroy()
    this.youtubeBlock?.destroy()
    this.editor?.destroy()
    this.toolbar = this.linkPopover = this.imageBlock = this.youtubeBlock = this.editor = null
    this.editorTarget.replaceChildren()
  }

  // --- Content -------------------------------------------------------------

  initialContent() {
    const json = this.jsonTarget.value.trim()
    if (json) {
      try {
        return JSON.parse(json)
      } catch {
        // A hand-edited or truncated value: fall through to the HTML.
      }
    }
    return this.htmlTarget.value || ""
  }

  sync() {
    if (!this.editor) return
    const html = this.editor.isEmpty ? "" : this.editor.getHTML()
    const json = JSON.stringify(this.editor.getJSON())
    this.htmlTarget.value = html
    this.jsonTarget.value = json
    this.dispatch("change", { detail: { html, json: this.editor.getJSON() } })
  }

  get value() {
    return this.getJSON()
  }

  getHTML() {
    return this.editor?.getHTML() ?? ""
  }

  getJSON() {
    return this.editor?.getJSON() ?? null
  }

  // Accepts editor JSON or an HTML string.
  setContent(content) {
    this.editor?.commands.setContent(content)
    this.sync()
  }

  // --- Pictures ------------------------------------------------------------

  // Uploads every image in `files` and inserts each at `position` (or at the
  // caret). Returns whether there was anything to handle, which is what a
  // ProseMirror handler needs to know.
  insertFiles(files, position = null) {
    const images = [...(files || [])].filter((file) => file.type.startsWith("image/"))
    if (images.length === 0) return false

    images.reduce(
      (previous, file) => previous.then(() => this.insertFile(file, position)),
      Promise.resolve()
    )
    return true
  }

  async insertFile(file, position) {
    const image = await this.uploader.upload(file)
    if (!image || !this.editor) return

    const node = { type: "image", attrs: { src: image.url, alt: image.alt } }
    const chain = this.editor.chain().focus()
    if (position == null) chain.insertContent(node).run()
    else chain.insertContentAt(position, node).run()
  }

  dropPosition(view, event) {
    return view.posAtCoords({ left: event.clientX, top: event.clientY })?.pos ?? null
  }

  // A picture dropped anywhere on the page, not only on the text, goes to the
  // end of the document. Dragging over the page shows the editor as the target
  // and stops the browser opening the file as a navigation.
  listenForPageDrops() {
    this.onPageDragOver = (event) => {
      if (!hasFiles(event)) return
      event.preventDefault()
      this.editorTarget.classList.add("editor--dropping")
    }
    this.onPageDragLeave = (event) => {
      if (event.relatedTarget === null) this.editorTarget.classList.remove("editor--dropping")
    }
    this.onPageDrop = (event) => {
      this.editorTarget.classList.remove("editor--dropping")
      if (!hasFiles(event) || this.editorTarget.contains(event.target)) return
      event.preventDefault()
      const end = this.editor.state.doc.content.size
      this.insertFiles(event.dataTransfer.files, end)
    }
    document.addEventListener("dragover", this.onPageDragOver)
    document.addEventListener("dragleave", this.onPageDragLeave)
    document.addEventListener("drop", this.onPageDrop)
  }

  stopListeningForPageDrops() {
    if (!this.onPageDrop) return
    document.removeEventListener("dragover", this.onPageDragOver)
    document.removeEventListener("dragleave", this.onPageDragLeave)
    document.removeEventListener("drop", this.onPageDrop)
    this.onPageDrop = this.onPageDragOver = this.onPageDragLeave = null
  }

  showStatus(message, failed = false) {
    let status = this.editorTarget.querySelector(".editor__status")
    if (!message) {
      status?.remove()
      return
    }
    if (!status) {
      status = document.createElement("p")
      status.className = "editor__status"
      status.setAttribute("role", "status")
      this.editorTarget.append(status)
    }
    status.textContent = message
    status.classList.toggle("editor__status--failed", failed)
    if (failed) setTimeout(() => status.remove(), 6000)
  }
}

function hasFiles(event) {
  return [...(event.dataTransfer?.types || [])].includes("Files")
}
