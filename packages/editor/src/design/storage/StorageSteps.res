open EpureVitest

// A stored section: its blocks, one markdown string each, and its atoms,
// one string each with the type on the first line, read into the model and
// written back. Without `canonical` the round trip is the identity; with
// it, the blocks come back in the canonical form.
type roundTrip = {
  blocks: array<string>,
  canonical?: array<string>,
  atoms?: dict<string>,
  canonicalAtoms?: dict<string>,
}

// The port's atoms, sorted by id as the port writes them.
let pairs = (atoms: option<dict<string>>): array<Section.atom> =>
  atoms
  ->Option.getOr(Dict.make())
  ->Dict.toArray
  ->Array.toSorted(((a, _), (b, _)) => String.compare(a, b))

let section = (blocks: array<string>, ~atoms=[]): Section.t => {
  id: "s",
  blocks: blocks->Array.mapWithIndex((text, index) => (Notation.letter(index), text)),
  atoms,
}

given1("a stored section", (_on, example: roundTrip) => {
  let expected = example.canonical->Option.getOr(example.blocks)
  let atoms = pairs(example.atoms)
  let written = Storage.write(Storage.read(section(example.blocks, ~atoms)), ~id="s")
  expect(written.blocks->Array.map(((_, text)) => text)).toEqual(expected)
  expect(written.atoms).toEqual(
    switch example.canonicalAtoms {
    | Some(canonical) => pairs(Some(canonical))
    | None => atoms
    },
  )
})

// An editor over a section: the document before, in the notation, the act,
// and the section `update` receives, one `@id text` line per block.
type edit = {
  before: string,
  @as("when") when_: JSON.t,
  update: string,
  atoms?: dict<string>,
  atomsAfter?: dict<string>,
}

let lines = (section: Section.t) =>
  section.blocks->Array.map(((id, text)) => `@${id} ${text}`)->Array.join("\n")

given1("an editor over a section", (_on, example: edit) => {
  let {doc} = Notation.read(example.before)
  let doc = {...doc, atoms: Storage.readAtoms(pairs(example.atoms))}
  let received = ref([])
  let storage: Section.storage = {
    sections: [Storage.write(doc, ~id="s")],
    update: sections => received := sections,
  }
  let result = Steps.acts(example.when_)->Array.reduce(doc, Steps.act)
  Storage.commit(storage, ~id="s", result)
  let update = example.update->String.trimEnd
  expect(received.contents->Array.map(lines)->Array.join("\n")).toBe(update)
  switch (example.atomsAfter, received.contents) {
  | (Some(atoms), [section]) => expect(section.atoms).toEqual(pairs(Some(atoms)))
  | (Some(_), _) => panic("one section was expected in the update")
  | (None, _) => ()
  }
})
