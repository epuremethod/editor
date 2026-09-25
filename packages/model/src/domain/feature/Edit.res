// The edits, each a pure function on the document. No function here touches
// the DOM.

let deleteBackward = (_doc: Doc.t): Doc.t => panic("Edit.deleteBackward is not implemented")

// Splits the block holding the caret. The first half keeps its id; the second
// takes `id`, which the caller minted.
let split = (_doc: Doc.t, ~id as _: Doc.id): Doc.t => panic("Edit.split is not implemented")

// The browser's input event: the block holding the focus, as the browser
// left it. `text` is the block's whole plain text and `anchor` and `focus`
// the selection inside it. The model diffs the old text against the new one
// to find the span that changed, so marks move with it. Composition, dead
// keys and autocorrect all land here.
let input = (_doc: Doc.t, ~text as _: string, ~anchor as _: int, ~focus as _: int): Doc.t =>
  panic("Edit.input is not implemented")
