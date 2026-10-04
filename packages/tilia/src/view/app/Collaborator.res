// A collaborator the demo simulates. Every five seconds it takes the
// section as it stood after the last landing, changes one thing on it with
// a line by a woman poet, and lands the result on the editor as a remote
// row. Every second change aims at the block that holds the local caret: it
// types a few words at the caret, splits the block there or joins it to a
// neighbour, to stress the merge where the reader types. The editor merges
// it through the host's port with whatever was typed since. The view's
// write on every act is not a save here: the host saves after each landing,
// so the typed text is everything since the last one.

open Editor

type t = {
  mutable on: bool,
  mutable row: Section.t,
  mutable last: string,
  mutable timer: option<intervalId>,
  mutable count: int,
  mutable ticks: int,
}

let make = (section: Section.t): t =>
  Tilia.tilia({on: false, row: section, last: "", timer: None, count: 0, ticks: 0})

let pick = (items: array<'a>) => items->Array.getUnsafe(Math.Int.random(0, items->Array.length))

let quoted = ((phrase, poet)) => `“${phrase}” (${poet})`

// A display holds one atom alone, so no words can join it.
let display = (text: string) => text->String.startsWith(":: ")

let formed = (text: string) =>
  display(text) || text->String.startsWith("#") || text->String.startsWith("- ")

let add = (sim: t): (Section.t, string) => {
  let line = pick(Poets.phrases)
  sim.count = sim.count + 1
  let id = `c${Int.toString(sim.count)}`
  let blocks = sim.row.blocks->Array.copy
  let at = Math.Int.random(0, blocks->Array.length + 1)
  blocks->Array.splice(~start=at, ~remove=0, ~insert=[(id, Pair.first(line))])
  ({...sim.row, blocks}, `added block ${id}: ${quoted(line)}`)
}

// The phrase goes between two words of the block, after its first word, so
// a heading or an item keeps its prefix.
let insert = (sim: t): (Section.t, string) => {
  let line = pick(Poets.phrases)
  let candidates = sim.row.blocks->Array.filter(((_, text)) => !display(text))
  switch candidates->Array.length {
  | 0 => add(sim)
  | _ =>
    let (id, text) = pick(candidates)
    let words = text->String.split(" ")
    let at = Math.Int.random(1, words->Array.length + 1)
    words->Array.splice(~start=at, ~remove=0, ~insert=[Pair.first(line)])
    let blocks =
      sim.row.blocks->Array.map(((other, held)) =>
        other == id ? (id, words->Array.join(" ")) : (other, held)
      )
    ({...sim.row, blocks}, `inserted into block ${id}: ${quoted(line)}`)
  }
}

// A join takes a plain block into the plain block above it.
let join = (sim: t): (Section.t, string) => {
  let blocks = sim.row.blocks
  let candidates = blocks->Array.filterWithIndex(((_, text), index) =>
    !formed(text) &&
    switch blocks->Array.get(index + 1) {
    | Some((_, next)) => !formed(next)
    | None => false
    }
  )
  switch candidates->Array.length {
  | 0 => add(sim)
  | _ =>
    let (id, text) = pick(candidates)
    let index = blocks->Array.findIndex(((other, _)) => other == id)
    let (gone, next) = blocks->Array.getUnsafe(index + 1)
    let joined = blocks->Array.copy
    joined->Array.splice(~start=index, ~remove=2, ~insert=[(id, text ++ " " ++ next)])
    ({...sim.row, blocks: joined}, `joined block ${gone} into block ${id}`)
  }
}

// The caret's place on the row's line: the shown line is written with a
// sentinel at the caret, and that place is carried to the row's line.
let sentinel = "\u{E000}"

let atCaret = (sim: t, doc: Doc.t): option<(Doc.id, int)> =>
  switch doc.selection {
  | Some({focus}) =>
    switch (
      Doc.block(doc, focus.block),
      sim.row.blocks->Array.find(((id, _)) => id == focus.block),
    ) {
    | (Some(block), Some((_, line))) if !display(line) =>
      let text = block.content.text
      let shift = at => at >= focus.offset ? at + 1 : at
      let content: Doc.text = {
        text: text->String.slice(~start=0, ~end=focus.offset) ++
        sentinel ++
        text->String.slice(~start=focus.offset),
        marks: block.content.marks->Array.map(mark => {
          ...mark,
          start: shift(mark.start),
          stop: shift(mark.stop),
        }),
      }
      let marked = Form.write(block.form, Inline.write(content, ~notation=false))
      let at = marked->String.indexOf(sentinel)
      let shown = marked->String.replace(sentinel, "")
      Some((focus.block, Typed.mapped(at, ~old=shown, ~new=line)))
    | _ => None
    }
  | None => None
  }

let blank = (text: string, at: int) => text->String.charAt(at)->String.trim == ""

let typeAt = (sim: t, id: Doc.id, at: int): (Section.t, string) => {
  let words = Pair.first(pick(Poets.phrases))->String.split(" ")
  let size = Math.Int.min(Math.Int.random(2, 4), words->Array.length)
  let from = Math.Int.random(0, words->Array.length - size + 1)
  let typed = words->Array.slice(~start=from, ~end=from + size)->Array.join(" ")
  let blocks = sim.row.blocks->Array.map(((other, line)) =>
    if other == id {
      let before = at == 0 || blank(line, at - 1) ? "" : " "
      let after = at == line->String.length || blank(line, at) ? "" : " "
      (
        id,
        line->String.slice(~start=0, ~end=at) ++
        before ++
        typed ++
        after ++
        line->String.slice(~start=at),
      )
    } else {
      (other, line)
    }
  )
  ({...sim.row, blocks}, `typed at the caret in block ${id}: “${typed}”`)
}

// The split falls on the space nearest before the caret, or after it, and
// never inside the prefix. The second half of an item stays an item.
let splitAt = (sim: t, id: Doc.id, at: int): (Section.t, string) => {
  let blocks = sim.row.blocks
  let index = blocks->Array.findIndex(((other, _)) => other == id)
  let (_, line) = blocks->Array.getUnsafe(index)
  let (form, _) = Form.read(line)
  let lead = Form.lead(form)->String.length
  let back = at > 0 ? line->String.lastIndexOfFrom(" ", at - 1) : -1
  let space = back >= lead ? back : line->String.indexOfFrom(" ", Math.Int.max(at, lead))
  if space <= lead || space >= line->String.length - 1 {
    typeAt(sim, id, at)
  } else {
    sim.count = sim.count + 1
    let fresh = `c${Int.toString(sim.count)}`
    let rest = line->String.slice(~start=space + 1)
    let split = blocks->Array.copy
    split->Array.splice(
      ~start=index,
      ~remove=1,
      ~insert=[
        (id, line->String.slice(~start=0, ~end=space)),
        (fresh, form == Item ? "- " ++ rest : rest),
      ],
    )
    ({...sim.row, blocks: split}, `split block ${id} at the caret into block ${fresh}`)
  }
}

// The join takes the next block into the caret's, or the caret's into the
// block above, when neither is a display.
let joinAt = (sim: t, id: Doc.id, at: int): (Section.t, string) => {
  let blocks = sim.row.blocks
  let index = blocks->Array.findIndex(((other, _)) => other == id)
  let joinable = at => blocks->Array.get(at)->Option.filter(((_, line)) => !display(line))
  let pairs = [
    joinable(index - 1)->Option.map(_ => index - 1),
    joinable(index + 1)->Option.map(_ => index),
  ]
  switch pairs->Array.filterMap(pair => pair) {
  | [] => typeAt(sim, id, at)
  | starts =>
    let start = pick(starts)
    let (kept, first) = blocks->Array.getUnsafe(start)
    let (gone, second) = blocks->Array.getUnsafe(start + 1)
    let joined = blocks->Array.copy
    joined->Array.splice(
      ~start,
      ~remove=2,
      ~insert=[(kept, first ++ " " ++ Pair.second(Form.read(second)))],
    )
    ({...sim.row, blocks: joined}, `joined block ${gone} into block ${kept} at the caret`)
  }
}

// A change aimed at the caret's block: words typed at the caret, a split
// or a join.
let aimed = (sim: t, doc: Doc.t): (Section.t, string) =>
  switch atCaret(sim, doc) {
  | None => insert(sim)
  | Some((id, at)) =>
    switch Math.Int.random(0, 3) {
    | 0 => typeAt(sim, id, at)
    | 1 => splitAt(sim, id, at)
    | _ => joinAt(sim, id, at)
    }
  }

// The remote row lands through the core, and only a block whose content
// changed is rebuilt. The host then saves, and the collaborator receives
// the save, so its next change starts from the section as shown.
let land = (sim: t, state: View.state, storage: Section.storage, remote: Section.t) => {
  ignore(View.land(state, storage, remote))
  View.save(state, storage)
  sim.row = state.live.typed.row
}

let tick = (sim: t, state: View.state, storage: Section.storage) => {
  sim.ticks = sim.ticks + 1
  let (remote, last) = switch Math.Int.random(0, 3) {
  | _ if mod(sim.ticks, 2) == 0 => aimed(sim, View.doc(state))
  | 0 => add(sim)
  | 1 => insert(sim)
  | _ => join(sim)
  }
  sim.last = last
  land(sim, state, storage, remote)
}

let start = (sim: t, state: View.state, storage: Section.storage) => {
  sim.row = Storage.write(View.doc(state), ~id=sim.row.id)
  sim.timer = Some(setInterval(() => tick(sim, state, storage), 5_000))
  sim.on = true
}

let stop = (sim: t) => {
  sim.timer->Option.forEach(clearInterval)
  sim.timer = None
  sim.on = false
  sim.last = ""
}

module Toggle = {
  @react.component
  let make = (~sim: t, ~state: View.state, ~storage: Section.storage) => {
    TiliaReact.useTilia()
    <p className="collaborator">
      <label>
        <input
          type_="checkbox"
          checked=sim.on
          onChange={_ => sim.on ? stop(sim) : start(sim, state, storage)}
        />
        {React.string(" simulate a collaborator, one change every five seconds")}
      </label>
      <span className="collaborator__last"> {React.string(sim.last)} </span>
    </p>
  }
}
