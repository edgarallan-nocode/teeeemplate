import { BlockPrompt } from "./block_prompt"

// Inserting an image: either a picture from this computer, which is uploaded
// and stored with the project, or an address elsewhere on the web. A dropped or
// pasted picture takes the same upload path without the prompt — see the
// controller.
export class ImageBlock {
  constructor(editor, { upload }) {
    this.prompt = new BlockPrompt(editor, {
      title: "Add an image",
      submit: "Insert from address",
      file: {
        label: "Upload a picture",
        accept: "image/png,image/jpeg,image/webp",
        onFile: (file) => upload(file)
      },
      fields: [
        { name: "src", label: "Image address", type: "url", placeholder: "or paste an address: https://…/picture.png", required: true },
        { name: "alt", label: "Alt text", placeholder: "What the picture shows" }
      ],
      validate: ({ src }) => (/^https?:\/\//i.test(src) ? null : "The address has to start with https://"),
      onSubmit: ({ src, alt }) => editor.chain().focus().setImage({ src, alt }).run()
    })
  }

  insert() {
    this.prompt.open()
  }

  destroy() {
    this.prompt.destroy()
  }
}
