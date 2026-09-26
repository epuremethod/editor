// One line of inline markdown, read into runs and written back out of them.
// The form is canonical: `**bold**`, `_italic_`, `` `code` `` and
// `[text](href)`, nested link outside, then bold, then italic, then code.
// A backslash keeps the character after it literal. In the notation the
// line may carry markers, `|` for the caret and `{` `}` for a selection, at
// any place; where a marker sits among the delimiters says which marks it
// holds. On the port there are no markers: those characters are text.

type marker = Caret | Open | Close

// A marker read off the line: where it sits in the plain text, and the
// marks open around it.
type found = {marker: marker, offset: int, kinds: array<Doc.kind>}

type read = {text: Doc.text, markers: array<found>}

type entry = {mutable kind: Doc.kind, start: int}

let fail = message => panic(`Inline: ${message}`)

// A reference: an id between double braces. Read before the markers, so
// `{{{a}}}` is a selected reference.
let reference = /^\{\{([A-Za-z0-9_-]+)\}\}/

let read = (source: string, ~notation=true): read => {
  let text = ref("")
  let stack: array<entry> = []
  let marks: array<Doc.mark> = []
  let markers: array<(marker, int, array<entry>)> = []
  let index = ref(0)
  let length = source->String.length
  let peek = ahead => source->String.charAt(index.contents + ahead)
  let top = () => stack->Array.get(stack->Array.length - 1)
  let inCode = () =>
    switch top() {
    | Some({kind: Code}) => true
    | _ => false
    }
  let open_ = kind => stack->Array.push({kind, start: text.contents->String.length})
  let close = () =>
    switch stack->Array.pop {
    | Some(entry) =>
      let stop = text.contents->String.length
      if stop > entry.start {
        marks->Array.push({kind: entry.kind, start: entry.start, stop})
      }
      entry
    | None => fail("a closing delimiter with nothing open")
    }
  let literal = character => text := text.contents ++ character
  while index.contents < length {
    let character = peek(0)
    switch character {
    | "\\" =>
      if index.contents + 1 >= length {
        fail("a backslash at the end of the line keeps nothing")
      }
      literal(peek(1))
      index := index.contents + 2
    | "{" if !inCode() && reference->RegExp.test(source->String.slice(~start=index.contents)) =>
      let found =
        reference->RegExp.exec(source->String.slice(~start=index.contents))->Option.getUnsafe
      let id = found->RegExp.Result.matches->Array.getUnsafe(0)->Option.getOr("")
      let whole = found->RegExp.Result.fullMatch
      open_(Ref(id))
      literal(whole)
      close()->ignore
      index := index.contents + whole->String.length
    | "|" | "{" | "}" if notation =>
      let marker = switch character {
      | "|" => Caret
      | "{" => Open
      | _ => Close
      }
      markers->Array.push((marker, text.contents->String.length, stack->Array.copy))
      index := index.contents + 1
    | "`" =>
      if inCode() {
        close()->ignore
      } else {
        open_(Code)
      }
      index := index.contents + 1
    | _ if inCode() =>
      literal(character)
      index := index.contents + 1
    | "*" if peek(1) == "*" =>
      switch top() {
      | Some({kind: Bold}) => close()->ignore
      | _ => open_(Bold)
      }
      index := index.contents + 2
    | "_" =>
      switch top() {
      | Some({kind: Italic}) => close()->ignore
      | _ => open_(Italic)
      }
      index := index.contents + 1
    | "[" =>
      open_(Link(""))
      index := index.contents + 1
    | "]" =>
      switch top() {
      | Some({kind: Link(_)}) => ()
      | _ => fail("a ] closes no link")
      }
      if peek(1) != "(" {
        fail("a link's text is followed by its href in parentheses")
      }
      index := index.contents + 2
      let href = ref("")
      let closed = ref(false)
      while !closed.contents {
        if index.contents >= length {
          fail("an href with no closing parenthesis")
        }
        let c = peek(0)
        if c == "\\" {
          href := href.contents ++ peek(1)
          index := index.contents + 2
        } else if c == ")" {
          closed := true
          index := index.contents + 1
        } else {
          href := href.contents ++ c
          index := index.contents + 1
        }
      }
      let entry = close()
      entry.kind = Link(href.contents)
      // The mark was pushed with an empty href; give it the one just read.
      let last = marks->Array.length - 1
      switch marks->Array.get(last) {
      | Some(mark) if mark.start == entry.start && mark.kind == Link("") =>
        marks->Array.set(last, {...mark, kind: Link(href.contents)})
      | _ => ()
      }
    | _ =>
      literal(character)
      index := index.contents + 1
    }
  }
  if stack->Array.length > 0 {
    fail("a mark left open at the end of the line")
  }
  {
    text: Runs.normalize({text: text.contents, marks}),
    markers: markers->Array.map(((marker, offset, held)) => {
      marker,
      offset,
      kinds: Runs.sorted(held->Array.map(entry => entry.kind)),
    }),
  }
}

// The characters a text keeps literal with a backslash: the delimiters, and
// in the notation the markers too. Inside a code span only the markers need
// it, since a delimiter there is text. On the port a double brace that is
// no reference takes a backslash on its first brace. A reference's text is
// written as it is.
let escape = (text: string, ~code, ~ref, ~notation) => {
  let pattern = switch (ref, code, notation) {
  | (true, _, _) => /(?!)/g

  | (_, true, true) => /[|{}]/g

  | (_, true, false) => /(?!)/g

  | (_, false, true) => /[\\|{}*_`\[\]]/g

  | (_, false, false) => /[\\*_`\[\]]|\{(?=\{)/g
  }
  text->String.replaceRegExp(pattern, "\\$&")
}

let escapeHref = (href: string) => href->String.replaceRegExp(/[\\)]/g, "\\$&")

let opening = (kind: Doc.kind) =>
  switch kind {
  | Bold => "**"
  | Italic => "_"
  | Code => "`"
  | Link(_) => "["
  | Ref(_) => ""
  }

let closing = (kind: Doc.kind) =>
  switch kind {
  | Bold => "**"
  | Italic => "_"
  | Code => "`"
  | Link(href) => `](${escapeHref(href)})`
  | Ref(_) => ""
  }

// A marker to write: the caret with the marks it holds, or one end of a
// selection.
type point = {marker: marker, offset: int, kinds: array<Doc.kind>}

let prefixOf = (a: array<Doc.kind>, b: array<Doc.kind>) =>
  a->Array.length <= b->Array.length &&
    a->Array.everyWithIndex((kind, index) => b->Array.get(index) == Some(kind))

let write = (content: Doc.text, ~points: array<point>=[], ~notation=true): string => {
  let text = content.text
  let length = text->String.length
  let boundaries = [0, length]
  content.marks->Array.forEach(mark => {
    boundaries->Array.push(mark.start)
    boundaries->Array.push(mark.stop)
  })
  points->Array.forEach(point => boundaries->Array.push(point.offset))
  let sorted = boundaries->Array.toSorted(Int.compare)
  let boundaries =
    sorted->Array.filterWithIndex((offset, index) =>
      index == 0 || sorted->Array.getUnsafe(index - 1) != offset
    )
  let out = ref("")
  let stack: array<Doc.kind> = []
  let emit = piece => out := out.contents ++ piece
  let pop = () =>
    switch stack->Array.pop {
    | Some(kind) => emit(closing(kind))
    | None => ()
    }
  let push = kind => {
    stack->Array.push(kind)
    emit(opening(kind))
  }
  let stateIs = kinds => stack == kinds
  boundaries->Array.forEachWithIndex((offset, index) => {
    let target = offset < length ? Runs.at(content, offset) : []
    let here = points->Array.filter(point => point.offset == offset)
    let caret = here->Array.find(point => point.marker == Caret)
    let opens = here->Array.some(point => point.marker == Open)
    let closes = here->Array.some(point => point.marker == Close)
    let placed = ref(false)
    let place = () =>
      switch caret {
      | Some(point) if !placed.contents && stateIs(point.kinds) =>
        emit("|")
        placed := true
      | _ => ()
      }
    place()
    while !prefixOf(stack, target) {
      pop()
      place()
    }
    if closes {
      emit("}")
    }
    if opens {
      emit("{")
    }
    target->Array.forEach(kind => {
      if !Runs.has(stack, kind) {
        push(kind)
        place()
      }
    })
    switch caret {
    | Some(point) if !placed.contents =>
      // No state on the way holds the caret's marks: open the missing ones
      // around it, empty.
      let extra = point.kinds->Array.filter(kind => !Runs.has(stack, kind))
      extra->Array.forEach(kind => emit(opening(kind)))
      emit("|")
      extra->Array.toReversed->Array.forEach(kind => emit(closing(kind)))
      placed := true
    | _ => ()
    }
    switch boundaries->Array.get(index + 1) {
    | Some(next) =>
      emit(
        escape(
          text->String.slice(~start=offset, ~end=next),
          ~code=Runs.has(target, Code),
          ~ref=target->Array.some(Runs.isRef),
          ~notation,
        ),
      )
    | None => ()
    }
  })
  out.contents
}
