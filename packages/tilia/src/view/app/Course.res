// What the dev page and the site's demo share: the demo page as one
// section, the storage that shows what the port received, and the mint.
// The page is its own demo: its title, its prose, its headings and its list
// of keys are blocks of the section, and all of it can be edited.

open Editor

type shown = {mutable last: string}

let section: Section.t = {
  id: "demo",
  blocks: [
    ("a", "# Demo"),
    (
      "b",
      "This page is the editor. Every block on it, this paragraph included, is a block of one section, and all of it can be edited. The section lives in memory: nothing is saved, and a reload brings the page back as it was.",
    ),
    (
      "c",
      "Under the last block is what the port receives after every act: the section whole, as markdown, one `@id text` line per block.",
    ),
    ("d", "## The keys"),
    ("e", "- Cmd+B, Cmd+I and Cmd+E mark the selection bold, italic or code."),
    ("f", "- Enter splits a block at the caret. On an empty item it leaves the list."),
    (
      "g",
      "- Backspace at the start of a block joins it to the block above, or turns a heading or an item back into prose first.",
    ),
    (
      "h",
      "- Cmd+Alt+1, 2 and 3 make a heading, Cmd+Alt+0 makes prose again, and Cmd+Shift+8 makes an item.",
    ),
    ("i", "- The arrows move the caret, and they cross from one block to the next."),
    (
      "j",
      "- Cmd+Shift+Up and Cmd+Shift+Down move a block. Paste puts each pasted line in a block of its own.",
    ),
    ("k", "## The section"),
    (
      "l",
      "A **topology** on a set X is a collection τ of subsets of X, called _open sets_, such that:",
    ),
    ("m", "The empty set and X itself are open."),
    ("n", "Any union of open sets is open, and any finite intersection of open sets is open."),
    (
      "o",
      "See [compactness](/compactness) for what a finite subcover buys, and `U` for a typical open set.",
    ),
    (
      "p",
      "A formula is an entry: {{f1}} sits inline, and the same kind of entry alone in a block is a display. Click one to edit its source. Cmd+M inserts a new one, and Cmd+Alt+4 makes a block holding one a display.",
    ),
    ("q", ":: {{f2}}"),
  ],
  entries: [
    ("f1", "math\nU \\in \\tau"),
    (
      "f2",
      "math\n\\bigcup_{i \\in I} U_i \\in \\tau \\quad\\text{for every family } (U_i)_{i \\in I} \\subseteq \\tau",
    ),
  ],
}

// The types the demo knows. A formula draws through KaTeX, inline or in
// display mode by its place, and enters the editor's box. A video draws
// its placement and opens a widget of its own on a click: here a plain
// field over its JSON, since the demo has no player.
type katexOptions = {displayMode: bool, throwOnError: bool}
@module("katex") external renderToString: (string, katexOptions) => string = "renderToString"

let math: View.render = (entry, ~display) =>
  <span
    className="math"
    dangerouslySetInnerHTML={{
      "__html": renderToString(entry.text, {displayMode: display, throwOnError: false}),
    }}
  />

let video: View.render = (entry, ~display as _) =>
  <span className="video"> {React.string("▶ " ++ entry.text)} </span>

let videoWidget: View.widget = (~entry, ~onChange, ~onClose) =>
  <textarea
    className="widget__source"
    defaultValue=entry.text
    rows=2
    onChange={event => onChange(ReactEvent.Form.target(event)["value"])}
    onKeyDown={event =>
      if ReactEvent.Keyboard.key(event) == "Escape" {
        onClose()
      }}
    onBlur={_ => onClose()}
  />

let types: dict<View.spec> = Dict.fromArray([
  ("math", {View.render: math}),
  ("video", {render: video, widget: videoWidget}),
])

let shown = Tilia.tilia({last: ""})

// The port writes the section whole, one `@id text` line per block.
let storage: Section.storage = {
  sections: [section],
  update: sections => {
    shown.last =
      sections
      ->Array.map(section =>
        section.blocks->Array.map(((id, text)) => `@${id} ${text}`)->Array.join("\n")
      )
      ->Array.join("\n\n")
  },
}

// What the port received last, as text. The host wraps it.
module Received = {
  @react.component
  let make = () => {
    TiliaReact.useTilia()
    React.string(shown.last)
  }
}

// The id a new block takes: the first letter no block holds, the way the
// model's harness mints, so a scenario that names ids reads the same here.
let mint = (state: View.state) =>
  () => {
    let taken = state.doc.blocks->Array.map(block => block.id)
    let rec free = index => {
      let id = Notation.letter(index)
      taken->Array.includes(id) ? free(index + 1) : id
    }
    free(0)
  }

// The id a new entry takes: `e1`, `e2` and on, the way the harness mints.
let mintEntry = (state: View.state) =>
  () => {
    let rec free = n => {
      let id = `e${Int.toString(n)}`
      state.doc.entries->Dict.has(id) ? free(n + 1) : id
    }
    free(1)
  }
