import { Extension } from "@tiptap/core"

// The one shortcut the starter kit does not own. Bold, italic, undo and redo
// come with their extensions; Cmd/Ctrl+K opens our link popover, which lives
// outside the editor and is handed in as a callback.
export const Shortcuts = Extension.create({
  name: "editorShortcuts",

  addOptions() {
    return { onLink: null }
  },

  addKeyboardShortcuts() {
    return {
      "Mod-k": () => {
        this.options.onLink?.()
        return true
      }
    }
  }
})
