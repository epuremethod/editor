open EpureVitest

// Steps for Typed.feature. A given table is read through the notation, so
// its cells hold the caret as `║` and a selection in `{` `}`. Every other
// table is the port's own text. The acts go through the Operations harness,
// so one harness drives both fixtures.

type blockRow = {block: string, text: string}
type atomRow = {atom: string, @as("type") type_: string, source: string}

let caret = "║"

let blocksOf = (table): array<Section.block> =>
  toRecords(table)->Array.map((row: blockRow) => (row.block, row.text))

let atomsOf = (table): array<Section.atom> =>
  toRecords(table)->Array.map((row: atomRow) => (row.atom, row.type_ ++ "\n" ++ row.source))

let isAtoms = (table: array<array<string>>) =>
  table->Array.get(0)->Option.flatMap(header => header->Array.get(0)) == Some("atom")

// The fixture's merge: a local block or atom where it differs from the
// base, the remote one otherwise, and what only the remote holds after.
let plain = (~base: Section.t, ~local: Section.t, ~remote: Section.t): Section.t => {
  let same = (held: array<(Doc.id, string)>, id, text) =>
    held->Array.find(((other, _)) => other == id) == Some((id, text))
  let merge = (base, local, remote) => {
    let kept = local->Array.filterMap(((id, text)) =>
      same(base, id, text) ? remote->Array.find(((other, _)) => other == id) : Some((id, text))
    )
    let added = remote->Array.filter(((id, _)) => local->Array.every(((other, _)) => other != id))
    Array.concat(kept, added)
  }
  {
    id: remote.id,
    blocks: merge(base.blocks, local.blocks, remote.blocks),
    atoms: merge(base.atoms, local.atoms, remote.atoms),
  }
}

// The section on screen, with the caret or the selection in its block.
let displayed = (doc: Doc.t): array<Section.block> =>
  doc.blocks->Array.map(block => (
    block.id,
    Form.write(
      block.form,
      Inline.write(block.content, ~points=Notation.points(doc, block)),
    )->String.replace("|", caret),
  ))

let unescaped = (text: string) => text->String.replaceAll("\\n", "\n")

given1("a section", (on, table: array<array<string>>) => {
  let source =
    blocksOf(table)
    ->Array.map(((id, text)) => `@${id} ${text->String.replace(caret, "|")}`)
    ->Array.join("\n")
  let {doc} = Notation.read(source)
  let row = Storage.write(doc, ~id="s")
  let state = ref(Typed.make(~row, ~doc))
  let received: ref<array<Section.t>> = ref([])
  let merges: ref<array<(Section.t, Section.t, Section.t)>> = ref([])
  let subject: ref<option<Section.t>> = ref(None)
  let storage: Section.storage = {
    sections: [row],
    update: sections => received := Array.concat(received.contents, sections),
    merge: (~base, ~local, ~remote) => {
      merges := Array.concat(merges.contents, [(base, local, remote)])
      plain(~base, ~local, ~remote)
    },
  }
  let act = said => state := Typed.act(state.contents, storage, doc => Steps.act(doc, said))
  let lastMerge = () =>
    switch merges.contents->Array.last {
    | Some(merge) => merge
    | None => panic("the merge function was not called")
    }

  on.step("its atoms", (table: array<array<string>>) =>
    switch subject.contents {
    | Some(section) => expect(section.atoms).toEqual(atomsOf(table))
    | None =>
      let atoms = atomsOf(table)
      let {row, doc} = state.contents
      state := Typed.make(~row={...row, atoms}, ~doc={...doc, atoms: Storage.readAtoms(atoms)})
    }
  )

  on.step("the person types {string}", (text: string) =>
    act(`input(${text->String.replace(caret, "|")})`)
  )
  on.step("the person presses backspace", () => act("backspace"))
  on.step("the person presses enter", () => act("enter"))
  on.step("the person presses bold", () => act("bold"))
  on.step("the person links the selection to {string}", (href: string) => act(`link(${href})`))
  on.step("the person pastes {string}", (source: string) => act(`paste(${unescaped(source)})`))
  on.step("the person clicks {string}", (text: string) => {
    let {doc: placed} = Notation.read(text->String.replace(caret, "|"), ~plain=true)
    switch (placed.blocks, placed.selection) {
    | ([{content: {text: plain}}], Some({focus: {offset}})) =>
      state :=
        Typed.act(state.contents, storage, doc =>
          switch doc.blocks->Array.find(block => block.content.text == plain) {
          | Some(block) =>
            Edit.select(doc, ~anchor={block: block.id, offset}, ~focus={block: block.id, offset})
          | None => panic(`No block reads "${plain}"`)
          }
        )
    | _ => panic("clicks takes the block's plain text with the caret where the click lands")
    }
  })
  on.step("the person moves the block up", () => act("moveUp"))
  on.step("the person edits atom {string} to read {string}", (id: string, text: string) =>
    act(`edit(${id}, ${text})`)
  )
  on.step("the host saves", () => state := Typed.save(state.contents, storage))
  on.step("a row lands", (table: array<array<string>>) =>
    state :=
      Typed.land(
        state.contents,
        storage,
        {id: "s", blocks: blocksOf(table), atoms: state.contents.row.atoms},
      )
  )

  on.step("the typed text is", (table: array<array<string>>) => {
    let typed = Typed.typed(state.contents)
    isAtoms(table)
      ? expect(typed.atoms).toEqual(atomsOf(table))
      : expect(typed.blocks).toEqual(blocksOf(table))
  })
  on.step("no typed text is left", () => {
    let typed = Typed.typed(state.contents)
    expect((typed.blocks, typed.atoms)).toEqual(([], []))
  })
  on.step("the row is", (table: array<array<string>>) =>
    expect(state.contents.row.blocks).toEqual(blocksOf(table))
  )
  on.step("the section shows", (table: array<array<string>>) => {
    subject := Some(Typed.shown(state.contents))
    expect(displayed(state.contents.doc)).toEqual(blocksOf(table))
  })
  on.step("the port receives", (table: array<array<string>>) => {
    subject := received.contents->Array.last
    expect(subject.contents->Option.map(section => section.blocks)).toEqual(Some(blocksOf(table)))
  })
  on.step("the port receives nothing", () => expect(received.contents).toEqual([]))
  on.step("the port's merge function receives the base", (table: array<array<string>>) => {
    let (base, _, _) = lastMerge()
    expect(base.blocks).toEqual(blocksOf(table))
  })
  on.step("it receives the local", (table: array<array<string>>) => {
    let (_, local, _) = lastMerge()
    subject := Some(local)
    expect(local.blocks).toEqual(blocksOf(table))
  })
  on.step("the port's merge function receives the local", (table: array<array<string>>) => {
    let (_, local, _) = lastMerge()
    subject := Some(local)
    expect(local.blocks).toEqual(blocksOf(table))
  })
  on.step("it receives the remote", (table: array<array<string>>) => {
    let (_, _, remote) = lastMerge()
    expect(remote.blocks).toEqual(blocksOf(table))
  })
})
