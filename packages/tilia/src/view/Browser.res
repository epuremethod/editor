// What the view needs from the browser, and nothing more: the selection,
// the nodes under a block, and the input events contentEditable fires.

type node = Dom.element
type selection
type event

@val @scope("document") external selected: unit => Nullable.t<selection> = "getSelection"
@val @scope("document") external active: Nullable.t<node> = "activeElement"
@val @scope("document") external listen: (string, event => unit) => unit = "addEventListener"
@val @scope("document") external unlisten: (string, event => unit) => unit = "removeEventListener"

@get external anchorNode: selection => Nullable.t<node> = "anchorNode"
@get external anchorOffset: selection => int = "anchorOffset"
@get external focusNode: selection => Nullable.t<node> = "focusNode"
@get external focusOffset: selection => int = "focusOffset"
@send external place: (selection, node, int, node, int) => unit = "setBaseAndExtent"

@get external nodeType: node => int = "nodeType"
@get external nodeValue: node => Nullable.t<string> = "nodeValue"
@get external rawText: node => string = "textContent"

// The plain text of a node. contentEditable writes a no-break space where
// a space touches an element's edge, and that is the browser's noise, not
// the text.
let textContent = (node: node) => node->rawText->String.replaceAll("\u00a0", " ")
@get external parent: node => Nullable.t<node> = "parentNode"
@get external children: node => 'list = "childNodes"
@val @scope("Array") external listed: 'list => array<node> = "from"
@send external closest: (node, string) => Nullable.t<node> = "closest"
@send external query: (node, string) => Nullable.t<node> = "querySelector"
@send external attribute: (node, string) => Nullable.t<string> = "getAttribute"
@send external setAttribute: (node, string, string) => unit = "setAttribute"
@send external contains: (node, node) => bool = "contains"
@send external position: (node, node) => int = "compareDocumentPosition"
@send external on: (node, string, event => unit) => unit = "addEventListener"
@send external off: (node, string, event => unit) => unit = "removeEventListener"
@send external focus: node => unit = "focus"

@get external inputType: event => string = "inputType"
@get external data: event => Nullable.t<string> = "data"
@get external composing: event => bool = "isComposing"
@send external prevent: event => unit = "preventDefault"

type transfer
@get external transfer: event => Nullable.t<transfer> = "dataTransfer"
@send external getData: (transfer, string) => string = "getData"

let isText = (node: node) => nodeType(node) == 3

// An atom is an element the browser may not edit, standing for the
// characters of a reference. Its `data-atom` attribute holds them, so the
// atom counts as that text wherever text is counted, whatever it draws.
let atomText = (node: node) => isText(node) ? None : node->attribute("data-atom")->Nullable.toOption

let isAtom = (node: node) => atomText(node)->Option.isSome

// The atom a node sits inside, if any.
let atomAround = (node: node) =>
  (isText(node) ? node->parent->Nullable.toOption : Some(node))->Option.flatMap(element =>
    element->closest("[data-atom]")->Nullable.toOption
  )

// Every unit of text under a node, in document order: a text node or an
// atom, never the nodes an atom draws.
let rec units = (node: node): array<node> =>
  isText(node) || isAtom(node) ? [node] : node->children->listed->Array.flatMap(units)

// Chrome holds no caret beside an atom at the edge of a block unless a text
// node stands there, so a zero-width space is written on each side of an
// atom. It is the browser's scaffolding, not text: it counts as nothing.
let zwsp = "\u200b"

let raw = (node: node) => node->nodeValue->Nullable.toOption->Option.getOr("")

let unitText = (node: node) =>
  switch atomText(node) {
  | Some(text) => text
  | None => raw(node)->String.replaceAll(zwsp, "")
  }

let length = (node: node) => unitText(node)->String.length

// The plain text under a node: contentEditable writes a no-break space where
// a space touches an element's edge, and that is the browser's noise, not
// the text. An atom counts as its reference.
let plainText = (node: node) =>
  units(node)->Array.map(unitText)->Array.join("")->String.replaceAll("\u00a0", " ")

// The text of every unit before `unit` in document order.
let before = (all: array<node>, unit: node) =>
  all
  ->Array.filter(other => Int.bitwiseAnd(unit->position(other), 2) != 0)
  ->Array.reduce(0, (sum, other) => sum + length(other))

// The plain-text offset inside `root` of a DOM position. A position inside
// an atom is its end, since the caret never sits inside one.
let offsetOf = (root: node, node: node, offset: int) => {
  let all = units(root)
  switch atomAround(node) {
  | Some(atom) => before(all, atom) + length(atom)
  | None =>
    if isText(node) {
      before(all, node) +
      raw(node)->String.slice(~start=0, ~end=offset)->String.replaceAll(zwsp, "")->String.length
    } else {
      let kids = node->children->listed
      switch kids->Array.get(offset) {
      | Some(child) => before(all, child)
      | None =>
        all
        ->Array.filter(unit => node->contains(unit))
        ->Array.reduce(0, (sum, unit) => sum + length(unit)) +
          all
          ->Array.filter(unit =>
            !(node->contains(unit)) && Int.bitwiseAnd(node->position(unit), 2) != 0
          )
          ->Array.reduce(0, (sum, unit) => sum + length(unit))
      }
    }
  }
}

@get external previous: node => Nullable.t<node> = "previousSibling"
@get external next: node => Nullable.t<node> = "nextSibling"

// The position beside an atom: in the text node that stands there, and in
// its parent when none does.
let beside = (atom: node, ~after) =>
  switch (after ? atom->next : atom->previous)->Nullable.toOption {
  | Some(text) if isText(text) => (text, after ? 0 : raw(text)->String.length)
  | _ =>
    let parent = atom->parent->Nullable.getUnsafe
    let index = parent->children->listed->Array.indexOf(atom)
    (parent, after ? index + 1 : index)
  }

// The raw index in a text node after `count` characters that count.
let rawIndex = (node: node, count: int) => {
  let text = raw(node)
  let rec seek = (index, seen) =>
    seen == count || index >= text->String.length
      ? index
      : seek(index + 1, text->String.charAt(index) == zwsp ? seen : seen + 1)
  seek(0, 0)
}

// The DOM position of a plain-text offset inside `root`. An offset at the
// edge of an atom is the position beside it.
let pointAt = (root: node, offset: int): (node, int) => {
  let all = units(root)
  let rec seek = (index, at) =>
    switch all->Array.get(index) {
    | Some(unit) =>
      let size = length(unit)
      if isAtom(unit) {
        if offset <= at {
          beside(unit, ~after=false)
        } else if offset <= at + size {
          beside(unit, ~after=true)
        } else {
          seek(index + 1, at + size)
        }
      } else if at + size >= offset {
        (unit, rawIndex(unit, offset - at))
      } else {
        seek(index + 1, at + size)
      }
    | None =>
      switch all->Array.get(all->Array.length - 1) {
      | Some(last) => isAtom(last) ? beside(last, ~after=true) : (last, length(last))
      | None => (root, 0)
      }
    }
  seek(0, 0)
}
