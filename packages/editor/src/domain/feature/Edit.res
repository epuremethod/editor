// The edits, each a pure function on the document. No function here touches
// the DOM.

let kindOf = (name: string): Doc.kind =>
  switch name {
  | "bold" => Bold
  | "italic" => Italic
  | "code" => Code
  | other => panic(`The mark ${other} is not known`)
  }

let indexOf = (doc: Doc.t, id) =>
  switch Doc.find(doc, id) {
  | Some(index) => index
  | None => panic(`The block ${id} is not in the document`)
  }

let blockAt = (doc: Doc.t, index) => doc.blocks->Array.getUnsafe(index)

let replace = (doc: Doc.t, index, content: Doc.text): Doc.t => {
  let blocks = doc.blocks->Array.copy
  blocks->Array.set(index, {...blockAt(doc, index), content})
  {...doc, blocks}
}

let caret = (block: Doc.id, offset, pending): option<Doc.selection> => Some({
  anchor: {block, offset},
  focus: {block, offset},
  pending,
})

// A display holds one reference alone. A block that no longer does, after
// any edit, is prose again.
let settle = (doc: Doc.t): Doc.t => {
  ...doc,
  blocks: doc.blocks->Array.map(block =>
    block.form == Display && !Runs.soleRef(block.content) ? {...block, form: Paragraph} : block
  ),
}

// Selects one reference whole, the way a backspace beside an atom does.
let selectMark = (doc: Doc.t, block: Doc.id, mark: Doc.mark): Doc.t => {
  ...doc,
  selection: Some({
    anchor: {block, offset: mark.start},
    focus: {block, offset: mark.stop},
    pending: [],
  }),
}

// The two ends of a selection in document order.
let ordered = (doc: Doc.t, selection: Doc.selection) => {
  let {anchor, focus} = selection
  let a = indexOf(doc, anchor.block)
  let f = indexOf(doc, focus.block)
  a < f || (a == f && anchor.offset <= focus.offset) ? (anchor, focus) : (focus, anchor)
}

let collapsed = (selection: Doc.selection) => selection.anchor == selection.focus

// Removes what a selection over a range holds. Across blocks: the first
// block is trimmed, the last is trimmed, the blocks between go, and the two
// ends join. The first id survives.
let deleteRange = (doc: Doc.t, selection: Doc.selection): Doc.t => {
  let (start, stop) = ordered(doc, selection)
  let from = indexOf(doc, start.block)
  let to = indexOf(doc, stop.block)
  if from == to {
    let content = Runs.splice(
      blockAt(doc, from).content,
      ~from=start.offset,
      ~to=stop.offset,
      ~inserted={text: "", marks: []},
    )
    settle({
      ...replace(doc, from, content),
      selection: caret(start.block, start.offset, Runs.before(content, start.offset)),
    })
  } else {
    let head = blockAt(doc, from)
    let first = head.content
    let last = blockAt(doc, to).content
    let content = Runs.concat(
      Runs.slice(first, ~from=0, ~to=start.offset),
      Runs.slice(last, ~from=stop.offset, ~to=last.text->String.length),
    )
    let blocks =
      doc.blocks
      ->Array.slice(~start=0, ~end=from)
      ->Array.concat([{Doc.id: start.block, form: head.form, content}])
      ->Array.concat(doc.blocks->Array.slice(~start=to + 1, ~end=doc.blocks->Array.length))
    settle({
      ...doc,
      blocks,
      selection: caret(start.block, start.offset, Runs.before(content, start.offset)),
    })
  }
}

type side = First | Second

// Two texts put end to end. A space parts them when both hold text and
// neither brings its own; the space takes the marks the two ends share.
let seamed = (a: Doc.text, b: Doc.text) => {
  let spaced =
    a.text != "" &&
    b.text != "" &&
    !Runs.blank(a.text, a.text->String.length - 1) &&
    !Runs.blank(b.text, 0)
  let seam = spaced
    ? {
        Doc.text: " ",
        marks: Runs.over(
          Runs.at(a, a.text->String.length - 1)->Array.filter(kind =>
            Runs.has(Runs.at(b, 0), kind)
          ),
          ~start=0,
          ~stop=1,
        ),
      }
    : {text: "", marks: []}
  (Runs.concat(Runs.concat(a, seam), b), seam.text->String.length)
}

// Joins a block with the one before it. The caret lands at the seam, on the
// side the caller says: the end of the first text or the start of the
// second.
let join = (doc: Doc.t, index, ~side): Doc.t => {
  let previous = blockAt(doc, index - 1)
  let current = blockAt(doc, index)
  let a = previous.content
  let (content, gap) = seamed(a, current.content)
  let offset = switch side {
  | First => a.text->String.length
  | Second => a.text->String.length + gap
  }
  let blocks =
    doc.blocks
    ->Array.slice(~start=0, ~end=index - 1)
    ->Array.concat([{Doc.id: previous.id, form: previous.form, content}])
    ->Array.concat(doc.blocks->Array.slice(~start=index + 1, ~end=doc.blocks->Array.length))
  settle({...doc, blocks, selection: caret(previous.id, offset, Runs.before(content, offset))})
}

// Backspace. Over a range it removes the range. At the start of a block it
// joins the block with the previous one. After an atom it selects the atom,
// so nothing invisible is ever removed. Elsewhere it removes the character
// before the caret.
let deleteBackward = (doc: Doc.t): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) if !collapsed(selection) => deleteRange(doc, selection)
  | Some({focus: {block, offset}}) =>
    let index = indexOf(doc, block)
    let here = blockAt(doc, index)
    switch Runs.refEnding(here.content, offset) {
    | Some(mark) => selectMark(doc, block, mark)
    | None =>
      if offset == 0 && here.form != Paragraph && here.form != Display {
        // A heading or an item turns back into prose before it joins. A
        // display joins at once, and its atom lands inline.
        let blocks = doc.blocks->Array.copy
        blocks->Array.set(index, {...here, form: Paragraph})
        {...doc, blocks}
      } else if offset == 0 {
        index == 0 ? doc : join(doc, index, ~side=Second)
      } else {
        let content = blockAt(doc, index).content
        let from = Runs.back(content.text, offset)
        let content = Runs.splice(content, ~from, ~to=offset, ~inserted={text: "", marks: []})
        settle({
          ...replace(doc, index, content),
          selection: caret(block, from, Runs.before(content, from)),
        })
      }
    }
  }

// Delete. Over a range it removes the range. At the end of a block it joins
// the next block onto it. Before an atom it selects the atom. Elsewhere it
// removes the character after the caret.
let deleteForward = (doc: Doc.t): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) if !collapsed(selection) => deleteRange(doc, selection)
  | Some({focus: {block, offset}}) =>
    let index = indexOf(doc, block)
    let content = blockAt(doc, index).content
    switch Runs.refStarting(content, offset) {
    | Some(mark) => selectMark(doc, block, mark)
    | None =>
      if offset == content.text->String.length {
        index + 1 < doc.blocks->Array.length ? join(doc, index + 1, ~side=First) : doc
      } else {
        let to = Runs.forward(content.text, offset)
        let content = Runs.splice(content, ~from=offset, ~to, ~inserted={text: "", marks: []})
        settle({
          ...replace(doc, index, content),
          selection: caret(block, offset, Runs.before(content, offset)),
        })
      }
    }
  }

let trailingBlank = (text: string, offset) => {
  let stop = ref(offset)
  while stop.contents > 0 && Runs.blank(text, stop.contents - 1) {
    stop := stop.contents - 1
  }
  stop.contents
}

let leadingBlank = (text: string, offset) => {
  let start = ref(offset)
  while start.contents < text->String.length && Runs.blank(text, start.contents) {
    start := start.contents + 1
  }
  start.contents
}

// The forms of the two halves of a split. Prose splits into prose. A
// heading follows its text: the half that holds it stays a heading, and an
// empty half is prose. An item splits into two items, so a list goes on. A
// display follows its atom, and the other half is prose.
let halves = (form: Doc.form, ~firstEmpty, ~secondEmpty): (Doc.form, Doc.form) =>
  switch form {
  | Paragraph => (Paragraph, Paragraph)
  | Item => (Item, Item)
  | Heading(_) | Display => firstEmpty && !secondEmpty ? (Paragraph, form) : (form, Paragraph)
  }

// Splits the block holding the caret. The first half keeps its id; the second
// takes `id`, which the caller minted. The spaces at the seam go. Over a
// range, the range goes first. Enter on an empty item leaves the list: the
// item turns into prose and nothing splits.
let rec split = (doc: Doc.t, ~id: Doc.id): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) if !collapsed(selection) => split(deleteRange(doc, selection), ~id)
  | Some({focus: {block, offset}}) =>
    let index = indexOf(doc, block)
    let here = blockAt(doc, index)
    let content = here.content
    if here.form == Item && content.text == "" {
      let blocks = doc.blocks->Array.copy
      blocks->Array.set(index, {...here, form: Paragraph})
      {...doc, blocks}
    } else {
      let first = Runs.slice(content, ~from=0, ~to=trailingBlank(content.text, offset))
      let second = Runs.slice(
        content,
        ~from=leadingBlank(content.text, offset),
        ~to=content.text->String.length,
      )
      let (firstForm, secondForm) = halves(
        here.form,
        ~firstEmpty=first.text == "",
        ~secondEmpty=second.text == "",
      )
      let blocks =
        doc.blocks
        ->Array.slice(~start=0, ~end=index)
        ->Array.concat([
          {Doc.id: block, form: firstForm, content: first},
          {id, form: secondForm, content: second},
        ])
        ->Array.concat(doc.blocks->Array.slice(~start=index + 1, ~end=doc.blocks->Array.length))
      settle({...doc, blocks, selection: caret(id, 0, [])})
    }
  }

let commonPrefix = (a: string, b: string, ~max) => {
  let n = ref(0)
  let limit = Math.Int.min(max, Math.Int.min(a->String.length, b->String.length))
  while n.contents < limit && a->String.charAt(n.contents) == b->String.charAt(n.contents) {
    n := n.contents + 1
  }
  n.contents
}

let commonSuffix = (a: string, b: string, ~max) => {
  let n = ref(0)
  let la = a->String.length
  let lb = b->String.length
  let limit = Math.Int.min(max, Math.Int.min(la, lb))
  while (
    n.contents < limit &&
      a->String.charAt(la - 1 - n.contents) == b->String.charAt(lb - 1 - n.contents)
  ) {
    n := n.contents + 1
  }
  n.contents
}

// The browser's input event: the block holding the focus, as the browser
// left it. `text` is the block's whole plain text and `anchor` and `focus`
// the selection inside it. The model diffs the old text against the new one
// to find the span that changed, so marks move with it. Composition, dead
// keys and autocorrect all land here. The diff stays inside the old
// selection's reach, so a letter typed beside its twin lands where the caret
// was. Inserted text takes the pending marks; text that replaces a selection
// takes the marks of the selection's first character.
let input = (doc: Doc.t, ~text: string, ~anchor: int, ~focus: int): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) =>
    let id = selection.focus.block
    let index = indexOf(doc, id)
    let old = blockAt(doc, index).content
    let (lo, hi) =
      selection.anchor.block == id
        ? (
            Math.Int.min(selection.anchor.offset, selection.focus.offset),
            Math.Int.max(selection.anchor.offset, selection.focus.offset),
          )
        : (selection.focus.offset, selection.focus.offset)
    let oldLength = old.text->String.length
    let newLength = text->String.length
    let prefix = commonPrefix(old.text, text, ~max=lo)
    let suffix = commonSuffix(
      old.text,
      text,
      ~max=Math.Int.min(oldLength - hi, Math.Int.min(oldLength, newLength) - prefix),
    )
    let from = prefix
    let to = oldLength - suffix
    let inserted = text->String.slice(~start=prefix, ~end=newLength - suffix)
    // Typed text is never a reference: what replaces a selected atom is text.
    let kinds =
      (to > from ? Runs.at(old, from) : selection.pending)->Array.filter(k => !Runs.isRef(k))
    // Punctuation typed at the end of a run lands outside it, and so does
    // a space typed at the end of a code span: what is typed then drops the
    // marks that end at the caret, and the caret keeps what it took.
    let ending =
      old.marks
      ->Array.filter(mark => mark.stop == from && mark.start < from)
      ->Array.map(mark => mark.kind)
    let outside = to == from && Runs.punctuation(inserted, ~spaces=Runs.has(ending, Code)) > 0
    let kinds = outside ? kinds->Array.filter(kind => !Runs.has(ending, kind)) : kinds
    let content = Runs.splice(
      old,
      ~from,
      ~to,
      ~inserted={text: inserted, marks: Runs.over(kinds, ~start=0, ~stop=inserted->String.length)},
    )
    let pending = inserted == "" ? Runs.before(content, focus) : kinds
    settle({
      ...replace(doc, index, content),
      selection: Some({
        anchor: {block: id, offset: anchor},
        focus: {block: id, offset: focus},
        pending,
      }),
    })
  }

// The span a selection covers in one block, by index.
let spanIn = (doc: Doc.t, selection: Doc.selection, index) => {
  let (start, stop) = ordered(doc, selection)
  let from = indexOf(doc, start.block)
  let to = indexOf(doc, stop.block)
  if index < from || index > to {
    None
  } else {
    let length = blockAt(doc, index).content.text->String.length
    Some((index == from ? start.offset : 0, index == to ? stop.offset : length))
  }
}

// Applies `change` to the span of every block the selection covers.
let overSelection = (doc: Doc.t, selection, change) =>
  doc.blocks->Array.reduceWithIndex(doc, (doc, _, index) =>
    switch spanIn(doc, selection, index) {
    | Some((from, to)) => replace(doc, index, change(blockAt(doc, index).content, ~from, ~to))
    | None => doc
    }
  )

// Toggles a mark over the selection. Over a caret it changes the pending
// marks. Over a range it removes the mark when every unit holds it and adds
// it otherwise, skipping code spans. Code drives bold and italic out of its
// span. The selection stays.
let toggle = (doc: Doc.t, ~mark: string): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) if collapsed(selection) =>
    let kind = kindOf(mark)
    let pending = Runs.has(selection.pending, kind)
      ? selection.pending->Array.filter(k => k != kind)
      : Runs.sorted(selection.pending->Array.concat([kind]))
    {...doc, selection: Some({...selection, pending})}
  | Some(selection) =>
    let kind = kindOf(mark)
    let all = doc.blocks->Array.everyWithIndex((block, index) =>
      switch spanIn(doc, selection, index) {
      | Some((from, to)) => Runs.covered(block.content, ~from, ~to, kind)
      | None => true
      }
    )
    overSelection(doc, selection, (content, ~from, ~to) =>
      if all {
        Runs.remove(content, ~from, ~to, kind)
      } else if kind == Code {
        content
        ->Runs.remove(~from, ~to, Bold)
        ->Runs.remove(~from, ~to, Italic)
        ->Runs.add(~from, ~to, Code)
      } else {
        Runs.add(content, ~from, ~to, kind)
      }
    )
  }

let isLink = (kind: Doc.kind) =>
  switch kind {
  | Link(_) => true
  | _ => false
  }

// Wraps the selection in a link to `href`, in place of any link it held.
// On a caret the link becomes pending.
let link = (doc: Doc.t, ~href: string): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) if collapsed(selection) =>
    let pending = Runs.sorted(
      selection.pending->Array.filter(kind => !isLink(kind))->Array.concat([Link(href)]),
    )
    {...doc, selection: Some({...selection, pending})}
  | Some(selection) =>
    overSelection(doc, selection, (content, ~from, ~to) => {
      let marks = content.marks->Array.flatMap(mark =>
        if !isLink(mark.kind) || mark.stop <= from || mark.start >= to {
          [mark]
        } else {
          let left = mark.start < from ? [{...mark, stop: from}] : []
          let right = mark.stop > to ? [{...mark, start: to}] : []
          left->Array.concat(right)
        }
      )
      Runs.normalize({
        ...content,
        marks: marks->Array.concat([{kind: Link(href), start: from, stop: to}]),
      })
    })
  }

// Places the selection where a click or a drag put it. A caret takes the
// marks of its place, and never sits inside an atom: it steps out of a
// reference, forward unless told otherwise. A range holds no pending marks.
// A selection placed in the blocks closes the box.
let select = (doc: Doc.t, ~anchor: Doc.point, ~focus: Doc.point, ~forward=true): Doc.t => {
  let content = blockAt(doc, indexOf(doc, focus.block)).content
  let (anchor, focus) =
    anchor == focus
      ? {
          let offset = Runs.snap(content, focus.offset, ~forward)
          ({...focus, offset}, {...focus, offset})
        }
      : (anchor, focus)
  let pending = anchor == focus ? Runs.placed(content, focus.offset) : []
  {...doc, selection: Some({anchor, focus, pending}), editing: None}
}

let placeAt = (doc: Doc.t, point: Doc.point, ~forward=true) =>
  select(doc, ~anchor=point, ~focus=point, ~forward)

// Whether an entry enters: the host says by its type. A reference to no
// entry never enters.
type enters = Doc.entry => bool

let entering = (doc: Doc.t, ~enters: enters, id: Doc.id) =>
  doc.entries->Dict.get(id)->Option.mapOr(false, enters)

// Opens the box of an entry at an offset of its source, the end when none
// is given. The block selection stays where it is.
let enter = (doc: Doc.t, ~id: Doc.id, ~offset=?): Doc.t =>
  switch doc.entries->Dict.get(id) {
  | Some(entry) => {
      ...doc,
      editing: Some({entry: id, offset: offset->Option.getOr(entry.text->String.length)}),
    }
  | None => doc
  }

// The reference the box was entered from: the one beside the block caret.
let entered = (doc: Doc.t, id: Doc.id) =>
  switch doc.selection {
  | Some({focus: {block, offset}}) =>
    let content = blockAt(doc, indexOf(doc, block)).content
    content.marks
    ->Array.find(mark => mark.kind == Ref(id) && (mark.start == offset || mark.stop == offset))
    ->Option.map(mark => (block, mark))
  | None => None
  }

// Closes the box and lands the caret beside the atom, after it unless told
// otherwise. Escape lands after.
let leave = (doc: Doc.t, ~after=true): Doc.t =>
  switch doc.editing {
  | None => doc
  | Some({entry}) =>
    switch entered(doc, entry) {
    | Some((block, mark)) => placeAt(doc, {block, offset: after ? mark.stop : mark.start})
    | None => {...doc, editing: None}
    }
  }

// Moves the caret one character forward and places it there. At the end of
// a block it moves to the start of the next one. A range collapses to its
// end. Before an atom that enters, it opens the box at the start of the
// source; inside the box it moves through the source, and at its end it
// leaves after the atom. Any other atom is stepped over whole.
let right = (doc: Doc.t, ~enters: enters): Doc.t =>
  switch (doc.editing, doc.selection) {
  | (Some({entry, offset}), _) =>
    switch doc.entries->Dict.get(entry) {
    | Some(text) if offset < text.text->String.length =>
      enter(doc, ~id=entry, ~offset=Runs.forward(text.text, offset))
    | _ => leave(doc, ~after=true)
    }
  | (None, None) => doc
  | (None, Some(selection)) if !collapsed(selection) =>
    let (_, stop) = ordered(doc, selection)
    placeAt(doc, stop)
  | (None, Some({focus: {block, offset}})) =>
    let index = indexOf(doc, block)
    let content = blockAt(doc, index).content
    switch Runs.refStarting(content, offset) {
    | Some({kind: Ref(id)}) if entering(doc, ~enters, id) => enter(doc, ~id, ~offset=0)
    | _ =>
      if offset < content.text->String.length {
        placeAt(doc, {block, offset: Runs.forward(content.text, offset)})
      } else {
        switch doc.blocks->Array.get(index + 1) {
        | Some(next) => placeAt(doc, {block: next.id, offset: 0})
        | None => doc
        }
      }
    }
  }

// Moves the caret one character back, the mirror of `right`.
let left = (doc: Doc.t, ~enters: enters): Doc.t =>
  switch (doc.editing, doc.selection) {
  | (Some({entry, offset}), _) =>
    switch doc.entries->Dict.get(entry) {
    | Some(text) if offset > 0 => enter(doc, ~id=entry, ~offset=Runs.back(text.text, offset))
    | _ => leave(doc, ~after=false)
    }
  | (None, None) => doc
  | (None, Some(selection)) if !collapsed(selection) =>
    let (start, _) = ordered(doc, selection)
    placeAt(doc, start)
  | (None, Some({focus: {block, offset}})) =>
    let index = indexOf(doc, block)
    let content = blockAt(doc, index).content
    switch Runs.refEnding(content, offset) {
    | Some({kind: Ref(id)}) if entering(doc, ~enters, id) => enter(doc, ~id)
    | _ =>
      if offset > 0 {
        placeAt(doc, {block, offset: Runs.back(content.text, offset)}, ~forward=false)
      } else {
        switch index > 0 ? Some(blockAt(doc, index - 1)) : None {
        | Some(previous) =>
          placeAt(doc, {block: previous.id, offset: previous.content.text->String.length})
        | None => doc
        }
      }
    }
  }

// The first and last block a selection covers, by index.
let reach = (doc: Doc.t, selection: Doc.selection) => {
  let (start, stop) = ordered(doc, selection)
  (indexOf(doc, start.block), indexOf(doc, stop.block))
}

let moveBlocks = (doc: Doc.t, ~from, ~to, ~by): Doc.t => {
  let moved = doc.blocks->Array.slice(~start=from, ~end=to + 1)
  let rest =
    doc.blocks
    ->Array.slice(~start=0, ~end=from)
    ->Array.concat(doc.blocks->Array.slice(~start=to + 1, ~end=doc.blocks->Array.length))
  let at = from + by
  let blocks =
    rest
    ->Array.slice(~start=0, ~end=at)
    ->Array.concat(moved)
    ->Array.concat(rest->Array.slice(~start=at, ~end=rest->Array.length))
  {...doc, blocks}
}

// Lifts the blocks the selection covers above the block before them. The
// selection travels with them, since ids and offsets do not change.
let moveUp = (doc: Doc.t): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) =>
    let (from, to) = reach(doc, selection)
    from == 0 ? doc : moveBlocks(doc, ~from, ~to, ~by=-1)
  }

// Lowers the blocks the selection covers under the block after them.
let moveDown = (doc: Doc.t): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) =>
    let (from, to) = reach(doc, selection)
    to + 1 >= doc.blocks->Array.length ? doc : moveBlocks(doc, ~from, ~to, ~by=1)
  }

// The references in pasted blocks that name an entry the document holds,
// one per reference in order. Each is copied under an id the caller mints,
// so two references never share one entry by accident.
let adopted = (doc: Doc.t, ~blocks: array<Doc.text>): array<Doc.id> =>
  blocks->Array.flatMap(text =>
    text.marks
    ->Array.toSorted((a, b) => Int.compare(a.start, b.start))
    ->Array.filterMap(mark =>
      switch mark.kind {
      | Ref(id) if doc.entries->Dict.has(id) => Some(id)
      | _ => None
      }
    )
  )

// Rewrites each adopted reference to its copy, last first so offsets hold.
let renamed = (text: Doc.text, ~take: Doc.id => option<Doc.id>): Doc.text => {
  let refs =
    text.marks
    ->Array.filter(mark => Runs.isRef(mark.kind))
    ->Array.toSorted((a, b) => Int.compare(a.start, b.start))
  let renames = refs->Array.filterMap(mark =>
    switch mark.kind {
    | Ref(id) => take(id)->Option.map(fresh => (mark, fresh))
    | _ => None
    }
  )
  renames
  ->Array.toReversed
  ->Array.reduce(text, (text, (mark, fresh)) => {
    let reference = "{{" ++ fresh ++ "}}"
    Runs.splice(
      text,
      ~from=mark.start,
      ~to=mark.stop,
      ~inserted={
        text: reference,
        marks: [{kind: Ref(fresh), start: 0, stop: reference->String.length}],
      },
    )
  })
}

// Pastes blocks at the caret, over the selection when there is one. One
// block goes into the text at the caret. Several split the block: the first
// pasted block joins the text before the caret, the last joins the text
// after, both the way a join does, and the rest sit between as new blocks.
// The new blocks take `ids`, one per block after the first, and the copied
// entries take `entryIds`, one per adopted reference, both minted by the
// caller. A reference to an entry the document does not hold stays as it
// is. The caret lands at the end of what was pasted.
let rec paste = (
  doc: Doc.t,
  ~blocks: array<Doc.text>,
  ~ids: array<Doc.id>,
  ~entryIds: array<Doc.id>=[],
): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) if !collapsed(selection) =>
    paste(deleteRange(doc, selection), ~blocks, ~ids, ~entryIds)
  | Some({focus: {block, offset}}) =>
    let olds = adopted(doc, ~blocks)
    if entryIds->Array.length != olds->Array.length {
      panic("paste takes one entry id for every reference it copies")
    }
    let entries = doc.entries->Dict.copy
    let next = ref(0)
    let take = old =>
      switch doc.entries->Dict.get(old) {
      | Some(entry) =>
        let fresh = entryIds->Array.getUnsafe(next.contents)
        next := next.contents + 1
        entries->Dict.set(fresh, entry)
        Some(fresh)
      | None => None
      }
    let blocks = blocks->Array.map(text => renamed(text, ~take))
    let doc = {...doc, entries}
    let index = indexOf(doc, block)
    let content = blockAt(doc, index).content
    let count = blocks->Array.length
    switch (blocks->Array.get(0), blocks->Array.get(count - 1)) {
    | (Some(first), Some(last)) if count == 1 =>
      last->ignore
      let content = Runs.splice(content, ~from=offset, ~to=offset, ~inserted=first)
      let offset = offset + first.text->String.length
      {
        ...replace(doc, index, content),
        selection: caret(block, offset, Runs.before(content, offset)),
      }
    | (Some(first), Some(last)) =>
      if ids->Array.length != count - 1 {
        panic("paste takes one id for every block after the first")
      }
      let (head, _) = seamed(Runs.slice(content, ~from=0, ~to=offset), first)
      let (tail, _) = seamed(
        last,
        Runs.slice(content, ~from=offset, ~to=content.text->String.length),
      )
      let between =
        blocks
        ->Array.slice(~start=1, ~end=count - 1)
        ->Array.mapWithIndex((text, at) => {
          Doc.id: ids->Array.getUnsafe(at),
          form: Paragraph,
          content: text,
        })
      let lastId = ids->Array.getUnsafe(count - 2)
      let blocks =
        doc.blocks
        ->Array.slice(~start=0, ~end=index)
        ->Array.concat([{Doc.id: block, form: blockAt(doc, index).form, content: head}])
        ->Array.concat(between)
        ->Array.concat([{id: lastId, form: Paragraph, content: tail}])
        ->Array.concat(doc.blocks->Array.slice(~start=index + 1, ~end=doc.blocks->Array.length))
      let offset = last.text->String.length
      settle({...doc, blocks, selection: caret(lastId, offset, Runs.before(tail, offset))})
    | _ => doc
    }
  }

// Sets the text of an entry. No block changes: the blocks hold references.
// When the entry's box is open, its caret lands at `offset`, the end of the
// text when none is given.
let edit = (doc: Doc.t, ~id: Doc.id, ~text: string, ~offset=?): Doc.t =>
  switch doc.entries->Dict.get(id) {
  | Some(entry) =>
    let entries = doc.entries->Dict.copy
    entries->Dict.set(id, {...entry, text})
    let editing = switch doc.editing {
    | Some({entry}) if entry == id =>
      Some({Doc.entry: id, offset: offset->Option.getOr(text->String.length)})
    | other => other
    }
    {...doc, entries, editing}
  | None => panic(`The entry ${id} is not in the document`)
  }

// Mints an entry under `id`, which the caller minted, and places its
// reference at the caret, over the selection when there is one. The caret
// lands after the atom.
let rec insert = (doc: Doc.t, ~id: Doc.id, ~type_: string, ~text: string): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) if !collapsed(selection) =>
    insert(deleteRange(doc, selection), ~id, ~type_, ~text)
  | Some({focus: {block, offset}}) =>
    let index = indexOf(doc, block)
    let reference = "{{" ++ id ++ "}}"
    let content = Runs.splice(
      blockAt(doc, index).content,
      ~from=offset,
      ~to=offset,
      ~inserted={
        text: reference,
        marks: [{kind: Ref(id), start: 0, stop: reference->String.length}],
      },
    )
    let offset = offset + reference->String.length
    let entries = doc.entries->Dict.copy
    entries->Dict.set(id, {type_, text})
    {
      ...replace(doc, index, content),
      entries,
      selection: caret(block, offset, Runs.placed(content, offset)),
    }
  }

// Sets the form of every block the selection covers. Setting the form a
// block already has turns it back into prose, so one key toggles. Only a
// block holding one reference alone takes the display form.
let form = (doc: Doc.t, ~form: Doc.form): Doc.t =>
  switch doc.selection {
  | None => doc
  | Some(selection) =>
    let (from, to) = reach(doc, selection)
    let covered = doc.blocks->Array.slice(~start=from, ~end=to + 1)
    let already = covered->Array.every(block => block.form == form)
    let blocks = doc.blocks->Array.mapWithIndex((block, index) =>
      if index < from || index > to {
        block
      } else if already {
        {...block, form: Paragraph}
      } else if form == Display && !Runs.soleRef(block.content) {
        block
      } else {
        {...block, form}
      }
    )
    {...doc, blocks}
  }
