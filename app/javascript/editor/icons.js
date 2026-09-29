// Inline SVG for the editor's menus and toolbar. One place, so an icon is the
// same wherever it appears, and small enough that a stylesheet-driven icon
// font would be more code than this.
const svg = (body) =>
  `<svg viewBox="0 0 16 16" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${body}</svg>`

export const icons = {
  heading: svg('<path d="M3 3v10M10 3v10M3 8h7"/><path d="M13.5 13V9.5l-1 .8" stroke-width="1.2"/>'),
  h1: svg('<path d="M2.5 3v10M8.5 3v10M2.5 8h6"/><path d="M13.5 13V8.5l-1.3 1" />'),
  h2: svg('<path d="M2.5 3v10M8.5 3v10M2.5 8h6"/><path d="M11.2 9.3c.3-.8 2.6-.8 2.6.4 0 1.2-2.6 2-2.6 3.3h2.8"/>'),
  h3: svg('<path d="M2.5 3v10M8.5 3v10M2.5 8h6"/><path d="M11.3 8.7h2.6l-1.6 1.7c1 0 1.7.5 1.7 1.3 0 .9-.8 1.4-1.6 1.4-.6 0-1.1-.2-1.4-.5"/>'),
  paragraph: svg('<path d="M9 3v10M12 3v10M12 3H7a3 3 0 0 0 0 6h2"/>'),
  blockquote: svg('<path d="M4 4.5c-1.3.5-2 1.6-2 3.5V11h3.5V7.5H3.6c0-1 .5-1.8 1.4-2.2zM11 4.5c-1.3.5-2 1.6-2 3.5V11h3.5V7.5h-1.9c0-1 .5-1.8 1.4-2.2z" fill="currentColor" stroke="none"/>'),
  code: svg('<path d="m5 5-3 3 3 3M11 5l3 3-3 3"/>'),
  codeBlock: svg('<rect x="2" y="2.5" width="12" height="11" rx="2"/><path d="m9.5 6-3 4"/>'),
  bulletList: svg('<path d="M6 4h8M6 8h8M6 12h8"/><circle cx="3" cy="4" r=".9" fill="currentColor"/><circle cx="3" cy="8" r=".9" fill="currentColor"/><circle cx="3" cy="12" r=".9" fill="currentColor"/>'),
  orderedList: svg('<path d="M6.5 4h7.5M6.5 8h7.5M6.5 12h7.5"/><path d="M2.2 3.2 3.3 2.6v3.2M2.2 9.6c.2-.6 1.6-.7 1.6 0s-1.6 1.2-1.6 2.4h1.8" stroke-width="1.2"/>'),
  upload: svg('<path d="M8 10.5V3.5M5 6.5l3-3 3 3M3 10.5v1.5a1.5 1.5 0 0 0 1.5 1.5h7a1.5 1.5 0 0 0 1.5-1.5v-1.5"/>'),
  image: svg('<rect x="2" y="2.5" width="12" height="11" rx="2"/><circle cx="6" cy="6.5" r="1.2"/><path d="m14 11-3.5-3.5L4 14"/>'),
  youtube: svg('<rect x="2" y="2.5" width="12" height="11" rx="2"/><path d="m6.5 5.5 4 2.5-4 2.5z" fill="currentColor" stroke="none"/>'),
  table: svg('<rect x="2" y="2" width="12" height="12" rx="2"/><path d="M2 6.5h12M2 10.5h12M8 2v12"/>'),
  link: svg('<path d="M6.5 9.5 9.5 6.5M7 4.5l1-1a2.5 2.5 0 0 1 3.5 3.5l-1 1M9 11.5l-1 1A2.5 2.5 0 0 1 4.5 9l1-1"/>'),
  bold: svg('<path d="M4.5 3h4a2.5 2.5 0 0 1 0 5h-4zM4.5 8h4.5a2.5 2.5 0 0 1 0 5h-4.5z"/>'),
  italic: svg('<path d="M10 3H7M9 13H6M9.5 3l-3 10"/>'),
  chevronRight: svg('<path d="m6 4 4 4-4 4"/>'),
  chevronDown: svg('<path d="m4 6 4 4 4-4"/>'),
  chevronLeft: svg('<path d="m10 4-4 4 4 4"/>'),
  trash: svg('<path d="M3 4.5h10M6.5 4.5v-1h3v1M4 4.5l.7 8.5h6.6l.7-8.5"/>'),
  rowAfter: svg('<rect x="2" y="2" width="12" height="12" rx="2"/><path d="M2 6.5h12M2 9.5h12M8 9.5v4.5M6 11.75h4"/>'),
  columnAfter: svg('<rect x="2" y="2" width="12" height="12" rx="2"/><path d="M6.5 2v12M9.5 2v12M9.5 8H14M11.75 6v4"/>'),
  check: svg('<path d="m3.5 8.5 3 3 6-7"/>')
}
