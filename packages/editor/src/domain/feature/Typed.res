// The editor over the port: the current row, landed or saved, and the
// displayed document. The typed text is what the document holds that the
// row does not. An act that keeps the block list changes the document
// alone; one that changes it saves. A landed row goes through the host's
// merge, and its answer is displayed.

type t = {row: Section.t, doc: Doc.t}

let make = (~row: Section.t, ~doc: Doc.t): t => {row, doc}

let ids = (doc: Doc.t) => doc.blocks->Array.map(block => block.id)

let shown = (state: t) => Storage.write(state.doc, ~id=state.row.id)

let save = (state: t, storage: Section.storage): t => {
  let section = shown(state)
  storage.update([section])
  {...state, row: section}
}

// Save timing follows the resulting block list: the same ids in the same
// order is typing, anything else is saved at once.
let act = (state: t, storage: Section.storage, edit: Doc.t => Doc.t): t => {
  let doc = edit(state.doc)
  let next = {...state, doc}
  ids(doc) == ids(state.doc) ? next : save(next, storage)
}

let differs = (held: array<(Doc.id, string)>, (id, text)) =>
  held->Array.find(((other, _)) => other == id) != Some((id, text))

// The blocks and atoms whose text differs from the row, in the document's
// order.
let typed = (state: t): Section.t => {
  let section = shown(state)
  {
    id: section.id,
    blocks: section.blocks->Array.filter(differs(state.row.blocks, ...)),
    atoms: section.atoms->Array.filter(differs(state.row.atoms, ...)),
  }
}

// An offset in the old text, in the new one: unchanged before the common
// prefix, shifted after the common suffix, and at the end of the changed
// span when it was inside it.
let mapped = (offset, ~old: string, ~new: string) => {
  let oldLength = old->String.length
  let newLength = new->String.length
  let prefix = Edit.commonPrefix(old, new, ~max=Math.Int.min(oldLength, newLength))
  let suffix = Edit.commonSuffix(old, new, ~max=Math.Int.min(oldLength, newLength) - prefix)
  if offset <= prefix {
    offset
  } else if offset >= oldLength - suffix {
    offset + newLength - oldLength
  } else {
    newLength - suffix
  }
}

let carried = (state: t, doc: Doc.t, point: Doc.point): option<Doc.point> =>
  switch (Doc.block(state.doc, point.block), Doc.block(doc, point.block)) {
  | (Some(was), Some(is)) =>
    Some({block: point.block, offset: mapped(point.offset, ~old=was.content.text, ~new=is.content.text)})
  | _ => None
  }

let land = (state: t, storage: Section.storage, remote: Section.t): t => {
  let answer = storage.merge(~base=state.row, ~local=shown(state), ~remote)
  let doc = Storage.read(answer)
  let selection = switch state.doc.selection {
  | Some({anchor, focus}) =>
    switch (carried(state, doc, anchor), carried(state, doc, focus)) {
    | (Some(anchor), Some(focus)) => Some({Doc.anchor, focus, pending: []})
    | _ => None
    }
  | None => None
  }
  let editing = switch state.doc.editing {
  | Some({atom, offset}) =>
    switch (state.doc.atoms->Dict.get(atom), doc.atoms->Dict.get(atom)) {
    | (Some(was), Some(is)) => Some({Doc.atom, offset: mapped(offset, ~old=was.text, ~new=is.text)})
    | _ => None
    }
  | None => None
  }
  {row: remote, doc: {...doc, selection, editing}}
}
