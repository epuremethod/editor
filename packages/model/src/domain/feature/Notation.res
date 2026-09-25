// The notation a scenario writes a document in, and the one it is read back
// out as. One line is one block. The text of the line is the block's text,
// `|` is the caret and `{` `}` hold a selection. A line may start with `@a `
// to name the block's id; a line that names none gets a letter by position.
// A backslash keeps the character after it literal.

type read = {doc: Doc.t, labeled: bool}

let letters = "abcdefghijklmnopqrstuvwxyz"

// The id a block gets from its position: `a` to `z`, then `aa`, `ab` and on.
let rec letter = index =>
  (index >= 26 ? letter(index / 26 - 1) : "") ++
  letters->String.charAt(mod(index, 26))

let labelLine = /^@([a-z][a-z0-9]*)(?: |$)/

type marker = Caret | Open | Close

type mutable_ = {
  mutable text: string,
  mutable markers: array<(marker, int)>,
}

let raise = (line, message) => panic(`Notation, line ${Int.toString(line)}: ${message}`)

let readLine = (raw, ~line) => {
  let (label, rest) = switch labelLine->RegExp.exec(raw) {
  | Some(found) =>
    let name = found->RegExp.Result.matches->Array.getUnsafe(0)->Option.getOr("")
    let whole = found->RegExp.Result.fullMatch
    (Some(name), raw->String.slice(~start=whole->String.length))
  | None => (None, raw)
  }
  let out = {text: "", markers: []}
  let escaped = ref(false)
  rest
  ->String.split("")
  ->Array.forEach(character => {
    if escaped.contents {
      out.text = out.text ++ character
      escaped := false
    } else {
      switch character {
      | "\\" => escaped := true
      | "|" => out.markers->Array.push((Caret, out.text->String.length))
      | "{" => out.markers->Array.push((Open, out.text->String.length))
      | "}" => out.markers->Array.push((Close, out.text->String.length))
      | other => out.text = out.text ++ other
      }
    }
  })
  if escaped.contents {
    raise(line, "a backslash at the end of the line keeps nothing")
  }
  (label, out.text, out.markers)
}

let read = (source: string): read => {
  let lines = source->String.endsWith("\n") ? source->String.slice(~start=0, ~end=-1) : source
  let anchor = ref(None)
  let focus = ref(None)
  let labeled = ref(false)
  let point = (id, offset, ~line, ~what) =>
    switch (anchor.contents, focus.contents) {
    | (None, None) => (Some({Doc.block: id, offset}), Some({Doc.block: id, offset}))
    | _ => raise(line, `a second ${what} when the document already holds a selection`)
    }
  let blocks = lines->String.split("\n")->Array.mapWithIndex((raw, index) => {
    let line = index + 1
    let (label, text, markers) = readLine(raw, ~line)
    let id = switch label {
    | Some(name) =>
      labeled := true
      name
    | None => letter(index)
    }
    markers->Array.forEach(((marker, offset)) =>
      switch marker {
      | Caret =>
        let (from, to) = point(id, offset, ~line, ~what="caret")
        anchor := from
        focus := to
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
    {Doc.id, content: {text, marks: []}}
  })
  let selection = switch (anchor.contents, focus.contents) {
  | (Some(anchor), Some(focus)) => Some({Doc.anchor, focus})
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

let escape = text =>
  text->String.replaceRegExp(/[\\|{}]/g, "\\$&")

// The block's text with the selection marks put back at their offsets. A
// selection over several blocks opens in one and closes in another.
let writeText = (block: Doc.block, selection: option<Doc.selection>) => {
  let text = block.content.text
  let at = offset => escape(text->String.slice(~start=0, ~end=offset))
  let from = offset => escape(text->String.slice(~start=offset))
  switch selection {
  | None => escape(text)
  | Some({anchor, focus}) if anchor == focus =>
    anchor.block == block.id ? at(anchor.offset) ++ "|" ++ from(anchor.offset) : escape(text)
  | Some({anchor, focus}) =>
    let opens = anchor.block == block.id
    let closes = focus.block == block.id
    switch (opens, closes) {
    | (true, true) =>
      let (start, stop) = (Math.Int.min(anchor.offset, focus.offset), Math.Int.max(anchor.offset, focus.offset))
      at(start) ++ "{" ++ escape(text->String.slice(~start, ~end=stop)) ++ "}" ++ from(stop)
    | (true, false) => at(anchor.offset) ++ "{" ++ from(anchor.offset)
    | (false, true) => at(focus.offset) ++ "}" ++ from(focus.offset)
    | (false, false) => escape(text)
    }
  }
}

let write = (doc: Doc.t, ~labels=false): string =>
  doc.blocks
  ->Array.map(block => {
    let text = writeText(block, doc.selection)
    let text = text->String.startsWith("@") ? "\\" ++ text : text
    labels ? `@${block.id} ${text}` : text
  })
  ->Array.join("\n")
