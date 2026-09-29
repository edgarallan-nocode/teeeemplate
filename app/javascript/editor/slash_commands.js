import { Extension } from "@tiptap/core"
import Suggestion from "@tiptap/suggestion"
import { SlashCommandMenu } from "./slash_command_menu"
import { commandGroups, filterGroups } from "./slash_command_items"

// `/` opens the block menu. The suggestion plugin owns the hard part — noticing
// the trigger, tracking the query as it is typed, and reporting where the caret
// is — and hands each change to a SlashCommandMenu, which draws it.
//
// Escape closes the menu for this `/`; deleting back past it and typing it
// again opens a fresh one. Selecting an item runs it with the range of the typed
// query, which the item deletes before inserting its block.
export const SlashCommands = Extension.create({
  name: "slashCommands",

  addOptions() {
    return { onImage: null, onYoutube: null }
  },

  addProseMirrorPlugins() {
    const groups = commandGroups(this.options)

    return [
      Suggestion({
        editor: this.editor,
        char: "/",
        allowSpaces: false,
        startOfLine: false,
        command: ({ editor, range, props }) => props.run({ editor, range }),
        items: ({ query }) => filterGroups(groups, query),
        render: () => {
          let menu = null

          return {
            onStart: (props) => {
              menu = new SlashCommandMenu(props)
            },
            onUpdate: (props) => menu?.update(props),
            onKeyDown: ({ event }) => {
              if (event.key === "Escape") {
                menu?.destroy()
                menu = null
                return true
              }
              return menu?.onKeyDown(event) ?? false
            },
            onExit: () => {
              menu?.destroy()
              menu = null
            }
          }
        }
      })
    ]
  }
})
