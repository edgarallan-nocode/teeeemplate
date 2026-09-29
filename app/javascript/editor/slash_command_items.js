import { icons } from "./icons"

// What the slash menu offers, grouped the way the menu shows it. Each item has
// an icon, a label, the words that should find it, and either `run` or a list
// of `children` (a submenu). `run` receives the editor and the range of the
// typed `/query`, which it deletes before inserting anything.
export function commandGroups({ onImage, onYoutube } = {}) {
  const clear = (editor, range) => editor.chain().focus().deleteRange(range)

  return [
    {
      label: "Formatting",
      items: [
        {
          label: "Heading",
          icon: icons.heading,
          keywords: ["h1", "h2", "h3", "title", "heading 1", "heading 2", "heading 3"],
          children: [1, 2, 3].map((level) => ({
            label: `Heading ${level}`,
            icon: icons[`h${level}`],
            keywords: [`h${level}`],
            run: ({ editor, range }) => clear(editor, range).setNode("heading", { level }).run()
          }))
        },
        {
          label: "Blockquote",
          icon: icons.blockquote,
          keywords: ["quote", "citation"],
          run: ({ editor, range }) => clear(editor, range).toggleBlockquote().run()
        },
        {
          label: "Inline Code",
          icon: icons.code,
          keywords: ["code", "mono", "monospace"],
          run: ({ editor, range }) => clear(editor, range).toggleCode().run()
        },
        {
          label: "Bulleted List",
          icon: icons.bulletList,
          keywords: ["ul", "bullets", "unordered"],
          run: ({ editor, range }) => clear(editor, range).toggleBulletList().run()
        },
        {
          label: "Numbered List",
          icon: icons.orderedList,
          keywords: ["ol", "ordered", "numbers"],
          run: ({ editor, range }) => clear(editor, range).toggleOrderedList().run()
        }
      ]
    },
    {
      label: "Blocks",
      items: [
        {
          label: "Image",
          icon: icons.image,
          keywords: ["picture", "photo", "img"],
          run: ({ editor, range }) => {
            clear(editor, range).run()
            onImage?.()
          }
        },
        {
          label: "YouTube",
          icon: icons.youtube,
          keywords: ["video", "embed", "yt"],
          run: ({ editor, range }) => {
            clear(editor, range).run()
            onYoutube?.()
          }
        },
        {
          label: "Code Block",
          icon: icons.codeBlock,
          keywords: ["pre", "snippet", "codeblock"],
          run: ({ editor, range }) => clear(editor, range).toggleCodeBlock().run()
        },
        {
          label: "Table",
          icon: icons.table,
          keywords: ["grid", "rows", "columns"],
          run: ({ editor, range }) =>
            clear(editor, range).insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run()
        }
      ]
    }
  ]
}

// The groups, narrowed to what the query matches. A parent matches when its
// own label does or any of its children's, so `/h1` still finds Heading.
export function filterGroups(groups, query) {
  const needle = query.trim().toLowerCase()
  if (!needle) return groups

  return groups
    .map((group) => ({ ...group, items: group.items.filter((item) => matches(item, needle)) }))
    .filter((group) => group.items.length > 0)
}

function matches(item, needle) {
  const words = [item.label, ...(item.keywords || []), ...(item.children || []).map((child) => child.label)]
  return words.some((word) => word.toLowerCase().includes(needle))
}
