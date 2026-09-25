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
@send external attribute: (node, string) => Nullable.t<string> = "getAttribute"
@send external contains: (node, node) => bool = "contains"
@send external position: (node, node) => int = "compareDocumentPosition"
@send external on: (node, string, event => unit) => unit = "addEventListener"
@send external off: (node, string, event => unit) => unit = "removeEventListener"

@get external inputType: event => string = "inputType"
@get external data: event => Nullable.t<string> = "data"
@get external composing: event => bool = "isComposing"
@send external prevent: event => unit = "preventDefault"

type transfer
@get external transfer: event => Nullable.t<transfer> = "dataTransfer"
@send external getData: (transfer, string) => string = "getData"

let isText = (node: node) => nodeType(node) == 3

// Every text node under a node, in document order.
let rec texts = (node: node): array<node> =>
  isText(node) ? [node] : node->children->listed->Array.flatMap(texts)

let length = (node: node) => node->nodeValue->Nullable.toOption->Option.getOr("")->String.length

// The plain-text offset inside `root` of a DOM position.
let offsetOf = (root: node, node: node, offset: int) => {
  let all = texts(root)
  if isText(node) {
    let before = ref(0)
    let found = ref(false)
    all->Array.forEach(text => {
      if text === node {
        found := true
      } else if !found.contents {
        before := before.contents + length(text)
      }
    })
    before.contents + offset
  } else {
    let kids = node->children->listed
    switch kids->Array.get(offset) {
    | Some(child) =>
      // The text that precedes the child in document order.
      all
      ->Array.filter(text => Int.bitwiseAnd(child->position(text), 2) != 0)
      ->Array.reduce(0, (sum, text) => sum + length(text))
    | None =>
      all
      ->Array.filter(text => node->contains(text))
      ->Array.reduce(0, (sum, text) => sum + length(text)) +
        all
        ->Array.filter(text =>
          !(node->contains(text)) && Int.bitwiseAnd(node->position(text), 2) != 0
        )
        ->Array.reduce(0, (sum, text) => sum + length(text))
    }
  }
}

// The DOM position of a plain-text offset inside `root`.
let pointAt = (root: node, offset: int): (node, int) => {
  let all = texts(root)
  let rec seek = (index, before) =>
    switch all->Array.get(index) {
    | Some(text) =>
      let size = length(text)
      before + size >= offset ? (text, offset - before) : seek(index + 1, before + size)
    | None =>
      switch all->Array.get(all->Array.length - 1) {
      | Some(last) => (last, length(last))
      | None => (root, 0)
      }
    }
  seek(0, 0)
}
