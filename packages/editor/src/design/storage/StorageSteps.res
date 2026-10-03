open EpureVitest

// A stored section: its blocks, one markdown string each, and its atoms,
// read into the model and written back. An atom is its text, with the type
// on the first line, or its text and its param. Without `canonical` the
// round trip is the identity; with it, the blocks come back in the
// canonical form.
type roundTrip = {
  blocks: array<string>,
  canonical?: array<string>,
  atoms?: dict<JSON.t>,
  canonicalAtoms?: dict<JSON.t>,
}

let paramOf = (json: option<JSON.t>): dict<string> =>
  switch json {
  | Some(Object(param)) =>
    param->Dict.mapValues(value =>
      switch value {
      | String(text) => text
      | _ => panic("A value of a param is a text")
      }
    )
  | None => Dict.make()
  | Some(_) => panic("A param is a dictionary of texts")
  }

let atomOf = (id, json: JSON.t): Section.atom =>
  switch json {
  | String(text) => {id, text, param: Dict.make()}
  | Object(fields) =>
    switch fields->Dict.get("text") {
    | Some(String(text)) => {id, text, param: paramOf(fields->Dict.get("param"))}
    | _ => panic(`The atom ${id} has no text`)
    }
  | _ => panic(`The atom ${id} is a text, or a text and a param`)
  }

// The port's atoms, sorted by id as the port writes them.
let pairs = (atoms: option<dict<JSON.t>>): array<Section.atom> =>
  atoms
  ->Option.getOr(Dict.make())
  ->Dict.toArray
  ->Array.toSorted(((a, _), (b, _)) => String.compare(a, b))
  ->Array.map(((id, json)) => atomOf(id, json))

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
  atoms?: dict<JSON.t>,
  atomsAfter?: dict<JSON.t>,
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
    merge: (~base as _, ~local as _, ~remote) => remote,
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
