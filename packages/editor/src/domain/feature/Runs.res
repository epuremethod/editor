// Marks over plain text: what covers an offset, what a slice keeps, what a
// splice moves, and the one normal form every edit leaves behind.

// The order marks nest in, outermost first.
let rank = (kind: Doc.kind) =>
  switch kind {
  | Link(_) => 0
  | Bold => 1
  | Italic => 2
  | Code => 3
  }

let has = (kinds: array<Doc.kind>, kind: Doc.kind) => kinds->Array.some(k => k == kind)

// Kinds in nesting order, each once.
let sorted = (kinds: array<Doc.kind>): array<Doc.kind> => {
  let out = []
  kinds
  ->Array.toSorted((a, b) => Int.compare(rank(a), rank(b)))
  ->Array.forEach(kind => {
    if !has(out, kind) {
      out->Array.push(kind)
    }
  })
  out
}

// Marks of a set of kinds over one span.
let over = (kinds: array<Doc.kind>, ~start, ~stop): array<Doc.mark> =>
  kinds->Array.map(kind => {Doc.kind, start, stop})

// The kinds covering the unit at `offset`.
let at = (text: Doc.text, offset: int) =>
  text.marks
  ->Array.filter(mark => mark.start <= offset && offset < mark.stop)
  ->Array.map(mark => mark.kind)
  ->sorted

// The kinds of the unit before `offset`; none at the start.
let before = (text: Doc.text, offset: int) => offset > 0 ? at(text, offset - 1) : []

// The kinds of the unit at `offset`; none at the end.
let after = (text: Doc.text, offset: int) =>
  offset < text.text->String.length ? at(text, offset) : []

let blank = (text: string, index: int) => text->String.charAt(index)->String.trim == ""

// Bold and italic never open or close on a space, and two runs of one of
// them parted by spaces alone are one run. A code span and a link keep
// their edges: a space inside them is content.
let soft = (kind: Doc.kind) =>
  switch kind {
  | Bold | Italic => true
  | Code | Link(_) => false
  }

let trim = (text: string, mark: Doc.mark): Doc.mark => {
  if soft(mark.kind) {
    let start = ref(mark.start)
    let stop = ref(mark.stop)
    while start.contents < stop.contents && blank(text, start.contents) {
      start := start.contents + 1
    }
    while stop.contents > start.contents && blank(text, stop.contents - 1) {
      stop := stop.contents - 1
    }
    {...mark, start: start.contents, stop: stop.contents}
  } else {
    mark
  }
}

let onlyBlank = (text: string, ~start, ~stop) => {
  let clean = ref(true)
  for index in start to stop - 1 {
    if !blank(text, index) {
      clean := false
    }
  }
  clean.contents
}

// The normal form: no empty mark, no two marks of one kind that touch,
// overlap or are parted by spaces alone, and marks sorted by start then by
// nesting order.
let normalize = (text: Doc.text): Doc.text => {
  let marks =
    text.marks
    ->Array.map(mark => trim(text.text, mark))
    ->Array.filter(mark => mark.stop > mark.start)
    ->Array.toSorted((a, b) =>
      switch Int.compare(rank(a.kind), rank(b.kind)) {
      | 0. => Int.compare(a.start, b.start)
      | other => other
      }
    )
  let merged: array<Doc.mark> = []
  marks->Array.forEach(mark => {
    switch merged->Array.get(merged->Array.length - 1) {
    | Some(last)
      if last.kind == mark.kind &&
        (mark.start <= last.stop ||
          (soft(mark.kind) && onlyBlank(text.text, ~start=last.stop, ~stop=mark.start))) =>
      merged->Array.set(
        merged->Array.length - 1,
        {...last, stop: Math.Int.max(last.stop, mark.stop)},
      )
    | _ => merged->Array.push(mark)
    }
  })
  let marks = merged->Array.toSorted((a, b) =>
    switch Int.compare(a.start, b.start) {
    | 0. => Int.compare(rank(a.kind), rank(b.kind))
    | other => other
    }
  )
  {...text, marks}
}

// The part of a text between two offsets, its marks clipped and moved to
// start at zero.
let slice = (text: Doc.text, ~from, ~to): Doc.text => {
  let marks = text.marks->Array.filterMap(mark => {
    let start = Math.Int.max(mark.start, from)
    let stop = Math.Int.min(mark.stop, to)
    stop > start ? Some({...mark, start: start - from, stop: stop - from}) : None
  })
  normalize({text: text.text->String.slice(~start=from, ~end=to), marks})
}

let shift = (marks: array<Doc.mark>, by: int) =>
  marks->Array.map(mark => {...mark, start: mark.start + by, stop: mark.stop + by})

let concat = (a: Doc.text, b: Doc.text): Doc.text =>
  normalize({
    text: a.text ++ b.text,
    marks: a.marks->Array.concat(shift(b.marks, a.text->String.length)),
  })

// Replaces the span between two offsets with `inserted`. A mark that spans
// the whole span stretches over the insert. A mark that ends or starts
// inside it is cut at the span. A mark that ends where the span begins, or
// begins where it ends, stays where it is: the inserted text's own marks
// decide what covers it.
let splice = (text: Doc.text, ~from, ~to, ~inserted: Doc.text): Doc.text => {
  let length = inserted.text->String.length
  let delta = length - (to - from)
  let kept = text.marks->Array.filterMap(mark => {
    if mark.stop <= from {
      Some(mark)
    } else if mark.start >= to {
      Some({...mark, start: mark.start + delta, stop: mark.stop + delta})
    } else if mark.start < from && mark.stop > to {
      Some({...mark, stop: mark.stop + delta})
    } else if mark.start < from {
      Some({...mark, stop: from})
    } else if mark.stop > to {
      Some({...mark, start: from + length, stop: mark.stop + delta})
    } else {
      None
    }
  })
  normalize({
    text: text.text->String.slice(~start=0, ~end=from) ++
    inserted.text ++
    text.text->String.slice(~start=to),
    marks: kept->Array.concat(shift(inserted.marks, from)),
  })
}

// Whether every unit of the span, code spans left out, carries `kind`.
let covered = (text: Doc.text, ~from, ~to, kind: Doc.kind) => {
  let all = ref(true)
  for offset in from to to - 1 {
    let kinds = at(text, offset)
    if !has(kinds, Code) && !has(kinds, kind) {
      all := false
    }
  }
  all.contents
}

// Removes every mark of `kind` from the span, keeping what reaches out of it.
let remove = (text: Doc.text, ~from, ~to, kind: Doc.kind): Doc.text => {
  let marks = text.marks->Array.flatMap(mark => {
    if mark.kind != kind || mark.stop <= from || mark.start >= to {
      [mark]
    } else {
      let left = mark.start < from ? [{...mark, stop: from}] : []
      let right = mark.stop > to ? [{...mark, start: to}] : []
      left->Array.concat(right)
    }
  })
  normalize({...text, marks})
}

// Adds `kind` over the span, skipping the units a code span covers.
let add = (text: Doc.text, ~from, ~to, kind: Doc.kind): Doc.text => {
  let marks = text.marks->Array.copy
  let start = ref(None)
  let close = stop =>
    switch start.contents {
    | Some(begin) =>
      marks->Array.push({Doc.kind, start: begin, stop})
      start := None
    | None => ()
    }
  for offset in from to to - 1 {
    let skipped = kind != Code && has(at(text, offset), Code)
    if skipped {
      close(offset)
    } else if start.contents == None {
      start := Some(offset)
    }
  }
  close(to)
  normalize({...text, marks})
}

let highSurrogate = (text: string, index: int) =>
  switch text->String.charCodeAt(index) {
  | Some(code) => code >= 0xD800 && code <= 0xDBFF
  | None => false
  }

let lowSurrogate = (text: string, index: int) =>
  switch text->String.charCodeAt(index) {
  | Some(code) => code >= 0xDC00 && code <= 0xDFFF
  | None => false
  }

// The offset one character on: two units when the character is a pair.
let forward = (text: string, offset: int) =>
  offset + 1 < text->String.length && highSurrogate(text, offset) && lowSurrogate(text, offset + 1)
    ? offset + 2
    : offset + 1

// The offset one character back.
let back = (text: string, offset: int) =>
  offset >= 2 && lowSurrogate(text, offset - 1) && highSurrogate(text, offset - 2)
    ? offset - 2
    : offset - 1

// The caret states at an offset, from the left side to the right: inside
// the marks that end there, between, inside the marks that start there.
// Each state is the set of pending marks it stands for.
let states = (text: Doc.text, offset: int): array<array<Doc.kind>> => {
  let common =
    text.marks
    ->Array.filter(mark => mark.start < offset && mark.stop > offset)
    ->Array.map(mark => mark.kind)
  let ending = text.marks->Array.filter(mark => mark.stop == offset)->Array.map(mark => mark.kind)
  let starting =
    text.marks->Array.filter(mark => mark.start == offset)->Array.map(mark => mark.kind)
  let out = []
  let push = kinds => {
    let state = sorted(kinds)
    if !(out->Array.some(seen => seen == state)) {
      out->Array.push(state)
    }
  }
  push(common->Array.concat(ending))
  push(common)
  push(common->Array.concat(starting))
  out
}
