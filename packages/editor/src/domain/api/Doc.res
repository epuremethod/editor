// The document the editor edits: a list of blocks and one selection. Every
// edit is a pure function from one document to the next.

type id = string

// What a mark is: bold, italic, a code span, a link to an href, or a
// reference to an atom by its id. A reference's text is the id between
// double braces, so offsets count it like any characters.
type kind = Bold | Italic | Code | Link(string) | Ref(string)

// A mark spans plain-text offsets of its block, `stop` excluded. Offsets
// count the units of the string, the same units the browser counts.
type mark = {kind: kind, start: int, stop: int}

type text = {text: string, marks: array<mark>}

// The form of a block: prose, a heading with its level, an item of a
// list, or a display, which holds one reference alone and draws it as a
// block. On the port the form is the line's prefix, `# `, `- ` or `:: `; in
// the model it is not text, so offsets count from the first letter.
type form = Paragraph | Heading(int) | Item | Display

type block = {id: id, form: form, content: text}

// A place in the document: a plain-text offset inside a block.
type point = {block: id, offset: int}

// A caret is a selection whose two ends are one point. `pending` holds the
// marks the next typed character takes; at a mark boundary the same offset
// has one state per side, and `pending` says which.
type selection = {anchor: point, focus: point, pending: array<kind>}

// An atom: a type the host knows, a text the type reads, and a param the
// app owns. A formula is an atom of type math whose text is its LaTeX
// source. The core knows no type and reads no key of a param.
type atom = {@as("type") type_: string, text: string, param: dict<string>}

// The box: an atom whose source is being edited, and the caret in it. It
// exists only for a type that enters. The block selection stays where the
// box was entered from, and the atom caret is the live one.
type editing = {atom: id, offset: int}

type t = {
  blocks: array<block>,
  selection: option<selection>,
  atoms: dict<atom>,
  editing: option<editing>,
}

let find = (doc: t, id: id) => doc.blocks->Array.findIndexOpt(block => block.id == id)

let block = (doc: t, id: id) => doc.blocks->Array.find(block => block.id == id)
