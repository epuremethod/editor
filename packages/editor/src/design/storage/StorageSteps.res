open EpureVitest

// A stored section: its blocks, one markdown string each, read into
// the model and written back. Without `canonical` the round trip is the
// identity; with it, the blocks come back in the canonical form.
type roundTrip = {blocks: array<string>, canonical?: array<string>}

let section = (blocks: array<string>): Section.t => {
  id: "s",
  blocks: blocks->Array.mapWithIndex((text, index) => (Notation.letter(index), text)),
}

given1("a stored section", (_on, example: roundTrip) => {
  let expected = example.canonical->Option.getOr(example.blocks)
  let written = Storage.write(Storage.read(section(example.blocks)), ~id="s")
  expect(written.blocks->Array.map(((_, text)) => text)).toEqual(expected)
})

// An editor over a section: the document before, in the notation, the act,
// and the section `update` receives, one `@id text` line per block.
type edit = {before: string, @as("when") when_: JSON.t, update: string}

let lines = (section: Section.t) =>
  section.blocks->Array.map(((id, text)) => `@${id} ${text}`)->Array.join("\n")

given1("an editor over a section", (_on, example: edit) => {
  let {doc} = Notation.read(example.before)
  let received = ref([])
  let storage: Section.storage = {
    sections: Dict.fromArray([("s", Storage.write(doc, ~id="s"))]),
    update: sections => received := sections,
  }
  let result = Steps.acts(example.when_)->Array.reduce(doc, Steps.act)
  Storage.commit(storage, ~id="s", result)
  let update = example.update->String.trimEnd
  expect(received.contents->Array.map(lines)->Array.join("\n")).toBe(update)
})
