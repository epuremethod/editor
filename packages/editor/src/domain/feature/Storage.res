// The two crossings of the port: a section read into the model, and the
// model written back as a section. Markdown on the outside, runs inside.
// An entry's type is its first line on the outside and a field inside.

let readEntry = (text: string): Doc.entry =>
  switch text->String.indexOf("\n") {
  | -1 => {type_: text, text: ""}
  | at => {type_: text->String.slice(~start=0, ~end=at), text: text->String.slice(~start=at + 1)}
  }

let writeEntry = (entry: Doc.entry) => entry.type_ ++ "\n" ++ entry.text

let readEntries = (entries: array<Section.entry>): dict<Doc.entry> =>
  entries->Array.map(((id, text)) => (id, readEntry(text)))->Dict.fromArray

// Sorted by id, so two copies of a section agree on the order of a field
// whose order means nothing.
let writeEntries = (entries: dict<Doc.entry>): array<Section.entry> =>
  entries
  ->Dict.toArray
  ->Array.toSorted(((a, _), (b, _)) => String.compare(a, b))
  ->Array.map(((id, entry)) => (id, writeEntry(entry)))

let read = (section: Section.t): Doc.t => {
  blocks: section.blocks->Array.map(((id, line)) => {
    let (form, text) = Form.read(line)
    {Doc.id, form, content: Inline.read(text, ~notation=false).text}
  }),
  selection: None,
  entries: readEntries(section.entries),
  editing: None,
}

let write = (doc: Doc.t, ~id: Doc.id): Section.t => {
  id,
  blocks: doc.blocks->Array.map(block => (
    block.id,
    Form.write(block.form, Inline.write(block.content, ~notation=false)),
  )),
  entries: writeEntries(doc.entries),
}

// Hands the host the section an edit changed.
let commit = (storage: Section.storage, ~id: Doc.id, doc: Doc.t) =>
  storage.update([write(doc, ~id)])
