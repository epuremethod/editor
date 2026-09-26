// The form of a block, read off the front of its markdown line and written
// back there: hashes for a heading, a dash for an item, two colons for a
// display, nothing for prose. A line that must start with a literal prefix
// escapes it.

let prefix = /^(#{1,3}) |^- |^:: /

let read = (line: string): (Doc.form, string) =>
  switch prefix->RegExp.exec(line) {
  | Some(found) =>
    let whole = found->RegExp.Result.fullMatch
    let rest = line->String.slice(~start=whole->String.length)
    switch found->RegExp.Result.matches->Array.getUnsafe(0) {
    | Some(hashes) => (Heading(hashes->String.length), rest)
    | None => (whole == ":: " ? Display : Item, rest)
    }
  | None => (Paragraph, line)
  }

let lead = (form: Doc.form) =>
  switch form {
  | Paragraph => ""
  | Heading(level) => "#"->String.repeat(level) ++ " "
  | Item => "- "
  | Display => ":: "
  }

// The line for a block: its prefix, then its text, with a backslash before
// a start that would otherwise read as a prefix. `#hashtag` and `-x` need
// none, since a prefix ends with a space.
let write = (form: Doc.form, text: string) => {
  let literal = prefix->RegExp.test(text)
  lead(form) ++ (literal ? "\\" : "") ++ text
}
