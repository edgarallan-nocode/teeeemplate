import { BlockPrompt } from "./block_prompt"

const YOUTUBE = /^(https?:\/\/)?((www|m)\.)?(youtube\.com|youtu\.be|youtube-nocookie\.com)\//i

// Inserting a YouTube embed. The extension turns a share link into an embed
// address; the server rebuilds it again through VideoSource before rendering,
// so what reaches a page is never the address that was pasted.
export class YouTubeBlock {
  constructor(editor) {
    this.prompt = new BlockPrompt(editor, {
      title: "Embed a YouTube video",
      submit: "Embed video",
      fields: [{ name: "src", label: "YouTube address", type: "url", placeholder: "https://www.youtube.com/watch?v=…", required: true }],
      validate: ({ src }) => (YOUTUBE.test(src) ? null : "That is not a YouTube address"),
      onSubmit: ({ src }) => editor.chain().focus().setYoutubeVideo({ src, width: 640, height: 360 }).run()
    })
  }

  insert() {
    this.prompt.open()
  }

  destroy() {
    this.prompt.destroy()
  }
}
