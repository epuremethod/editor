// The notation a scenario writes a document in, and the one it is read back
// out as. One line is one block. The text of the line is the block's text
// in inline markdown, `|` is the caret and `{` `}` hold a selection. A line
// may start with `@a ` to name the block's id; a line that names none gets
// a letter by position. A backslash keeps the character after it literal.

type read = {doc: Doc.t, labeled: bool}

let letters = "abcdefghijklmnopqrstuvwxyz"

// The id a block gets from its position: `a` to `z`, then `aa`, `ab` and on.
let rec letter = index =>
  (index >= 26 ? letter(index / 26 - 1) : "") ++ letters->String.charAt(mod(index, 26))

let labelLine = /^@([a-z][a-z0-9]*)(?: |$)/

let raise = (line, message) => panic(`Notation, line ${Int.toString(line)}: ${message}`)

// The delimiters of inline markdown, kept literal when a line is plain.
let quote = (text: string) => text->String.replaceRegExp(/[*_`\[\]]/g, "\\$&")

let readLine = (raw, ~plain) => {
  let (label, rest) = switch labelLine->RegExp.exec(raw) {
  | Some(found) =>
    let name = found->RegExp.Result.matches->Array.getUnsafe(0)->Option.getOr("")
    let whole = found->RegExp.Result.fullMatch
    (Some(name), raw->String.slice(~start=whole->String.length))
  | None => (None, raw)
  }
  let {text, markers} = Inline.read(plain ? quote(rest) : rest)
  (label, text, markers)
}

// Reads a document. A plain source holds no marks: its delimiters are text,
// the way the browser hands a block back.
let read = (source: string, ~plain=false): read => {
  let lines = source->String.endsWith("\n") ? source->String.slice(~start=0, ~end=-1) : source
  let anchor = ref(None)
  let focus = ref(None)
  let pending = ref([])
  let labeled = ref(false)
  let blocks =
    lines
    ->String.split("\n")
    ->Array.mapWithIndex((raw, index) => {
      let line = index + 1
      let (label, content, markers) = readLine(raw, ~plain)
      let id = switch label {
      | Some(name) =>
        labeled := true
        name
      | None => letter(index)
      }
      markers->Array.forEach(({marker, offset, kinds}) =>
        switch marker {
        | Caret =>
          if anchor.contents != None {
            raise(line, "a caret when the document already holds a selection")
          }
          anchor := Some({Doc.block: id, offset})
          focus := Some({Doc.block: id, offset})
          pending := kinds
        | Open =>
          if anchor.contents != None {
            raise(line, "a second { when the document already holds a selection")
          }
          anchor := Some({Doc.block: id, offset})
        | Close =>
          if anchor.contents == None {
            raise(line, "a } before any {")
          }
          if focus.contents != None {
            raise(line, "a second }")
          }
          focus := Some({Doc.block: id, offset})
        }
      )
      {Doc.id, content}
    })
  let selection = switch (anchor.contents, focus.contents) {
  | (Some(anchor), Some(focus)) => Some({Doc.anchor, focus, pending: pending.contents})
  | (Some(_), None) => raise(lines->String.split("\n")->Array.length, "a { without its }")
  | _ => None
  }
  let seen = Set.make()
  blocks->Array.forEachWithIndex((block, index) => {
    if seen->Set.has(block.id) {
      raise(index + 1, `the id ${block.id} is used twice`)
    }
    seen->Set.add(block.id)
  })
  {doc: {blocks, selection}, labeled: labeled.contents}
}

// The markers a block writes: its caret, or the end of the selection it
// holds. A selection over several blocks opens in one and closes in another.
let points = (doc: Doc.t, block: Doc.block): array<Inline.point> =>
  switch doc.selection {
  | None => []
  | Some({anchor, focus, pending}) if anchor == focus =>
    anchor.block == block.id ? [{marker: Caret, offset: anchor.offset, kinds: pending}] : []
  | Some({anchor, focus}) =>
    let index = id => Doc.find(doc, id)->Option.getOr(-1)
    let (start, stop) =
      index(anchor.block) < index(focus.block) ||
        (anchor.block == focus.block && anchor.offset <= focus.offset)
        ? (anchor, focus)
        : (focus, anchor)
    let out = []
    if start.block == block.id {
      out->Array.push({Inline.marker: Open, offset: start.offset, kinds: []})
    }
    if stop.block == block.id {
      out->Array.push({Inline.marker: Close, offset: stop.offset, kinds: []})
    }
    out
  }

let write = (doc: Doc.t, ~labels=false): string =>
  doc.blocks
  ->Array.map(block => {
    let text = Inline.write(block.content, ~points=points(doc, block))
    let text = text->String.startsWith("@") ? "\\" ++ text : text
    labels ? `@${block.id} ${text}` : text
  })
  ->Array.join("\n")
