// The document the editor edits: a list of blocks and one selection. Every
// edit is a pure function from one document to the next.

type id = string

// A mark spans plain-text offsets of its block, `stop` excluded.
type mark = {kind: string, start: int, stop: int}

type text = {text: string, marks: array<mark>}

type block = {id: id, content: text}

// A place in the document: a plain-text offset inside a block.
type point = {block: id, offset: int}

// A caret is a selection whose two ends are one point.
type selection = {anchor: point, focus: point}

type t = {blocks: array<block>, selection: option<selection>}

let find = (doc: t, id: id) => doc.blocks->Array.findIndexOpt(block => block.id == id)
