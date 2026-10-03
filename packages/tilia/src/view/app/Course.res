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
      "A formula is an atom: {{f1}} sits inline, and the same kind of atom alone in a block is a display. Click one to edit its source. Cmd+M inserts a new one, and Cmd+Alt+4 makes a block holding one a display.",
    ),
    ("q", ":: {{f2}}"),
  ],
  atoms: [
    {id: "f1", text: "math\nU \\in \\tau", param: Dict.make()},
    {
      id: "f2",
      text: "math\n\\bigcup_{i \\in I} U_i \\in \\tau \\quad\\text{for every family } (U_i)_{i \\in I} \\subseteq \\tau",
      param: Dict.make(),
    },
  ],
}

// The types the demo knows. A formula draws through KaTeX, inline or in
// display mode by its place, and enters the editor's box. A video draws
// its placement and opens a widget of its own on a click: here a plain
// field over its JSON, since the demo has no player.
type katexOptions = {displayMode: bool, throwOnError: bool}
@module("katex") external renderToString: (string, katexOptions) => string = "renderToString"

let math: View.render = (atom, ~display) =>
  <span
    className="math"
    dangerouslySetInnerHTML={{
      "__html": renderToString(atom.text, {displayMode: display, throwOnError: false}),
    }}
  />

let video: View.render = (atom, ~display as _) =>
  <span className="video"> {React.string("▶ " ++ atom.text)} </span>

let videoWidget: View.widget = (~atom, ~onChange, ~onClose) =>
  <textarea
    className="widget__source"
    defaultValue=atom.text
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

// One side's change to a text: the span of the base it replaces, and what
// it puts there.
type change = {start: int, stop: int, text: string}

let change = (base: string, side: string) => {
  let size = Math.Int.min(base->String.length, side->String.length)
  let prefix = Edit.commonPrefix(base, side, ~max=size)
  let suffix = Edit.commonSuffix(base, side, ~max=size - prefix)
  {
    start: prefix,
    stop: base->String.length - suffix,
    text: side->String.slice(~start=prefix, ~end=side->String.length - suffix),
  }
}

// A text both sides changed: two changes that do not overlap both land, and
// the reader's text stands otherwise. Two insertions at one place land the
// reader's first. A stand-in for radif's merge, word by word, until the demo
// can take it.
let text = (~base: string, ~local: string, ~remote: string) =>
  if local == base {
    remote
  } else if remote == base || remote == local {
    local
  } else {
    let mine = change(base, local)
    let theirs = change(base, remote)
    if mine.start < theirs.stop && theirs.start < mine.stop {
      local
    } else {
      let (first, second) =
        (theirs.start, theirs.stop) < (mine.start, mine.stop) ? (theirs, mine) : (mine, theirs)
      base->String.slice(~start=0, ~end=first.start) ++
      first.text ++
      base->String.slice(~start=first.stop, ~end=second.start) ++
      second.text ++
      base->String.slice(~start=second.stop)
    }
  }

// The host's merge: a block or atom both sides changed merges its text, a
// block or atom the reader typed is kept, one the reader removed and the
// remote left alone stays removed, the remote one is taken otherwise, and
// the remote order stands. A typed block the remote dropped
// keeps its place after the block it followed on screen. A param merges
// whole: the reader's stands when the reader changed it.
let merge = (~base: Section.t, ~local: Section.t, ~remote: Section.t): Section.t => {
  let three = (base, local, remote, ~id, ~merged) => {
    let entry = (entries, key) => entries->Array.find(other => id(other) == key)
    let typed = local->Array.filter(mine => entry(base, id(mine)) != Some(mine))
    let out = remote->Array.filterMap(theirs =>
      switch (entry(typed, id(theirs)), entry(base, id(theirs)), entry(local, id(theirs))) {
      | (Some(mine), Some(was), _) => Some(merged(~was, ~mine, ~theirs))
      | (Some(mine), None, _) => Some(mine)
      | (None, Some(was), None) if was == theirs => None
      | (None, _, _) => Some(theirs)
      }
    )
    typed->Array.forEach(mine =>
      if entry(remote, id(mine)) == None {
        let rec after = index =>
          switch local->Array.get(index) {
          | None => 0
          | Some(previous) =>
            switch out->Array.findIndex(other => id(other) == id(previous)) {
            | -1 => after(index - 1)
            | at => at + 1
            }
          }
        let index = local->Array.findIndex(other => id(other) == id(mine))
        out->Array.splice(~start=after(index - 1), ~remove=0, ~insert=[mine])
      }
    )
    out
  }
  {
    id: remote.id,
    blocks: three(
      base.blocks,
      local.blocks,
      remote.blocks,
      ~id=((id, _)) => id,
      ~merged=(~was as (_, was), ~mine as (id, mine), ~theirs as (_, theirs)) => (
        id,
        text(~base=was, ~local=mine, ~remote=theirs),
      ),
    ),
    atoms: three(
      base.atoms,
      local.atoms,
      remote.atoms,
      ~id=(atom: Section.atom) => atom.id,
      ~merged=(~was: Section.atom, ~mine: Section.atom, ~theirs: Section.atom) => {
        id: mine.id,
        text: text(~base=was.text, ~local=mine.text, ~remote=theirs.text),
        param: mine.param != was.param ? mine.param : theirs.param,
      },
    ),
  }
}

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
  merge,
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

// The id a new atom takes: `e1`, `e2` and on, the way the harness mints.
let mintAtom = (state: View.state) =>
  () => {
    let rec free = n => {
      let id = `e${Int.toString(n)}`
      state.doc.atoms->Dict.has(id) ? free(n + 1) : id
    }
    free(1)
  }
