// The two crossings of the port: a section read into the model, and the
// model written back as a section. Markdown on the outside, runs inside.

let read = (section: Section.t): Doc.t => {
  blocks: section.blocks->Array.map(((id, line)) => {
    let (form, text) = Form.read(line)
    {Doc.id, form, content: Inline.read(text, ~notation=false).text}
  }),
  selection: None,
}

let write = (doc: Doc.t, ~id: Doc.id): Section.t => {
  id,
  blocks: doc.blocks->Array.map(block => (
    block.id,
    Form.write(block.form, Inline.write(block.content, ~notation=false)),
  )),
}

// Hands the host the section an edit changed.
let commit = (storage: Section.storage, ~id: Doc.id, doc: Doc.t) =>
  storage.update([write(doc, ~id)])
