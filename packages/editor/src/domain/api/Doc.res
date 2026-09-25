// The document the editor edits: a list of blocks and one selection. Every
// edit is a pure function from one document to the next.

type id = string

// What a mark is: bold, italic, a code span, or a link to an href.
type kind = Bold | Italic | Code | Link(string)

// A mark spans plain-text offsets of its block, `stop` excluded. Offsets
// count the units of the string, the same units the browser counts.
type mark = {kind: kind, start: int, stop: int}

type text = {text: string, marks: array<mark>}

// The form of a block: prose, a heading with its level, or an item of a
// list. On the port the form is the line's prefix, `# ` or `- `; in the
// model it is not text, so offsets count from the first letter.
type form = Paragraph | Heading(int) | Item

type block = {id: id, form: form, content: text}

// A place in the document: a plain-text offset inside a block.
type point = {block: id, offset: int}

// A caret is a selection whose two ends are one point. `pending` holds the
// marks the next typed character takes; at a mark boundary the same offset
// has one state per side, and `pending` says which.
type selection = {anchor: point, focus: point, pending: array<kind>}

type t = {blocks: array<block>, selection: option<selection>}

let find = (doc: t, id: id) => doc.blocks->Array.findIndexOpt(block => block.id == id)

let block = (doc: t, id: id) => doc.blocks->Array.find(block => block.id == id)
