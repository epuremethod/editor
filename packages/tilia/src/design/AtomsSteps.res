open EpureVitest
open Editor

// Steps for Atoms.feature. The view renders into jsdom, and the acts go
// through it. The image rule is the editor's own, over a fake loader that
// reads a tilia table of records and remembers each run.

%%raw("globalThis.IS_REACT_ACT_ENVIRONMENT = true")

// React's `act` with a callback that returns nothing: the work is flushed
// before it returns.
@module("react") external act: (unit => unit) => unit = "act"

@val @scope("document") external createElement: string => Dom.element = "createElement"
@val @scope(("document", "body")) external appendToBody: Dom.element => unit = "appendChild"
@send external querySelector: (Dom.element, string) => Nullable.t<Dom.element> = "querySelector"
@send external dispatchEvent: (Dom.element, Dom.event) => unit = "dispatchEvent"
@new external mouseEvent: (string, {"bubbles": bool}) => Dom.event = "MouseEvent"
@get external textContent: Dom.element => string = "textContent"
@get external alt: Dom.element => string = "alt"
@get @scope("style") external styleWidth: Dom.element => string = "width"

type blockRow = {block: string, text: string}
type atomRow = {atom: string, rule: string, source: string, param?: string}
type recordRow = {
  record: string,
  title: string,
  description: string,
  width: string,
  height: string,
  bytes: string,
}
type liveRow = {atom: string, live: string}
type runRow = {atom: string, source: string, previous: string}
type idRow = {atom: string}

type record = {
  title: string,
  description: string,
  width: int,
  height: int,
  mutable bytes: string,
}
type run = {atom: string, source: string, previous: string}

let caret = "║"

let paramOf = (written: string): dict<string> =>
  written
  ->String.split(", ")
  ->Array.filter(pair => pair != "")
  ->Array.map(pair =>
    switch pair->String.indexOf("=") {
    | -1 => panic(`A param is key=value pairs, not ${pair}`)
    | at => (pair->String.slice(~start=0, ~end=at), pair->String.slice(~start=at + 1))
    }
  )
  ->Dict.fromArray

let sorted = (param: dict<string>) =>
  param->Dict.toArray->Array.toSorted(((a, _), (b, _)) => String.compare(a, b))

let atomsOf = (table): array<Section.atom> =>
  toRecords(table)->Array.map((row: atomRow): Section.atom => {
    id: row.atom,
    text: row.rule ++ "\n" ++ row.source,
    param: paramOf(row.param->Option.getOr("")),
  })

let blocksOf = (table): array<Section.block> =>
  toRecords(table)->Array.map((row: blockRow) => (
    row.block,
    row.text->String.replace(caret, ""),
  ))

let int = text =>
  switch Int.fromString(text) {
  | Some(value) => value
  | None => panic(`${text} is not a number`)
  }

let sized = (meta: Image.meta) =>
  `${meta.record}, ${Int.toString(meta.width)} × ${Int.toString(meta.height)}`

let shown = (image: Image.t) =>
  switch image {
  | Loading({meta: Some(meta)}) => `Loading(${sized(meta)})`
  | Loading({record}) => `Loading(${record})`
  | Missing(id) => `Missing(${id})`
  | Ready({meta}) => `Ready(${sized(meta)})`
  }

let math: Rule.t = Rule.make({
  param: Rule.raw,
  first: atom => atom,
  render: (atom, ~param as _, ~display as _) =>
    <span className="math"> {React.string(atom.text)} </span>,
})

given1("a section", (on, table: array<array<string>>) => {
  let source =
    toRecords(table)
    ->Array.map((row: blockRow) => `@${row.block} ${row.text->String.replace(caret, "|")}`)
    ->Array.join("\n")
  let given = ref(Notation.read(source).doc)
  let records: dict<record> = Tilia.tilia(Dict.make())
  let runs: array<run> = []

  let loader = (atom: Rule.atom, previous: Image.t, set: Image.t => unit) => {
    let text = atom.text
    runs->Array.push({atom: atom.id, source: text, previous: shown(previous)})
    switch records->Dict.get(text) {
    | None => set(Missing(text))
    | Some(found) =>
      let meta: Image.meta = {
        record: text,
        object: text,
        width: found.width,
        height: found.height,
        title: found.title,
        description: found.description,
      }
      switch found.bytes {
      | "device" => set(Ready({meta, src: "blob:" ++ text}))
      | "remote" => set(Loading({record: text, meta: Some(meta), blob: None}))
      | _ => ()
      }
    }
  }

  // The test editor holds the callbacks of the editor last opened.
  let opened: ref<option<(Rule.change => unit, unit => unit)>> = ref(None)
  let image = Rule.make({
    ...Image.rule(~loader),
    editor: (_, ~param as _, ~onChange, ~onClose) => {
      opened := Some((onChange, onClose))
      <div className="editor" />
    },
  })
  let rules = Dict.fromArray([("math", math), ("image", image)])

  let received: ref<array<Section.t>> = ref([])
  let storage: Section.storage = {
    sections: [],
    update: sections => received := Array.concat(received.contents, sections),
    merge: (~base as _, ~local as _, ~remote) => remote,
  }

  let built: ref<option<(View.state, Dom.element)>> = ref(None)
  let before: dict<unknown> = Dict.make()

  let ensure = () =>
    switch built.contents {
    | Some(done) => done
    | None =>
      let row = Storage.write(given.contents, ~id="s")
      let state = View.prepare(row, ~rules)
      View.load(state, given.contents)
      let container = createElement("div")
      appendToBody(container)
      let root = ReactDOM.Client.createRoot(container)
      act(() => root->ReactDOM.Client.Root.render(<View state storage />))
      on.test.onTestFinished(_ => act(() => root->ReactDOM.Client.Root.unmount()))
      let live = state.live
      before->Dict.set("atoms", Obj.magic(live.atoms))
      before->Dict.set("live", Obj.magic(live.live))
      live.atoms
      ->Dict.toArray
      ->Array.forEach(((id, atom)) => {
        before->Dict.set("atom " ++ id, Obj.magic(atom))
        before->Dict.set("param " ++ id, Obj.magic(atom.param))
        before->Dict.set("live " ++ id, Obj.magic(live.live->Dict.get(id)))
      })
      built := Some((state, container))
      (state, container)
    }

  // A landed row waits for its atoms, the next step, and lands with none
  // when no atoms follow.
  let landing: ref<option<array<Section.block>>> = ref(None)
  let land = (atoms: array<Section.atom>) =>
    landing.contents->Option.forEach(blocks => {
      landing := None
      let (state, _) = ensure()
      act(() => ignore(View.land(state, storage, {id: "s", blocks, atoms})))
    })
  let settled = () => {
    land([])
    ensure()
  }

  let apply = (edit: Doc.t => Doc.t) => {
    let (state, _) = settled()
    act(() => View.act(state, storage, edit))
  }
  let doc = () => {
    let (state, _) = settled()
    state.live.typed.doc
  }
  let drawn = (id: string) => {
    let (_, container) = settled()
    switch container->querySelector(`[data-ref="${id}"]`)->Nullable.toOption {
    | Some(element) => element
    | None => panic(`No atom ${id} is drawn`)
    }
  }
  let click = (id: string) => {
    let atom = drawn(id)
    act(() => atom->dispatchEvent(mouseEvent("mousedown", {"bubbles": true})))
  }
  let editorOf = (id: string) => {
    let (state, _) = settled()
    if state.editor != Some(id) {
      click(id)
    }
    switch opened.contents {
    | Some(callbacks) => callbacks
    | None => panic(`The editor of atom ${id} did not open`)
    }
  }
  let atomOf = (id: string) => {
    let (state, _) = settled()
    switch state.live.atoms->Dict.get(id) {
    | Some(atom) => atom
    | None => panic(`No atom ${id}`)
    }
  }
  let same = (key: string, now: unknown) =>
    switch before->Dict.get(key) {
    | Some(was) => expect(now === was).toBe(true)
    | None => panic(`Nothing was held as ${key} before the first act`)
    }

  on.step("its atoms", (table: array<array<string>>) =>
    switch landing.contents {
    | Some(_) => land(atomsOf(table))
    | None =>
      given := {...given.contents, atoms: Storage.readAtoms(atomsOf(table))}
    }
  )
  on.step("the records", (table: array<array<string>>) =>
    toRecords(table)->Array.forEach((row: recordRow) =>
      records->Dict.set(
        row.record,
        Tilia.tilia({
          title: row.title,
          description: row.description,
          width: int(row.width),
          height: int(row.height),
          bytes: row.bytes,
        }),
      )
    )
  )

  on.step("the person clicks atom {string}", (id: string) => click(id))
  on.step("the person types {string}", (text: string) => {
    let at = text->String.indexOf(caret)
    let plain = text->String.replace(caret, "")
    apply(doc => Edit.input(doc, ~text=plain, ~anchor=at, ~focus=at))
  })
  on.step("the person edits atom {string} to read {string}", (id: string, text: string) =>
    apply(doc => Edit.edit(doc, ~id, ~text))
  )
  on.step("the person places atom {string} at {string}", (id: string, param: string) =>
    apply(doc => Edit.place(doc, ~id, ~param=paramOf(param)))
  )
  on.step("a row lands", (table: array<array<string>>) => {
    ignore(ensure())
    landing := Some(blocksOf(table))
  })
  on.step("the bytes of record {string} arrive", (id: string) => {
    ignore(settled())
    switch records->Dict.get(id) {
    | Some(found) => act(() => found.bytes = "device")
    | None => panic(`No record ${id}`)
    }
  })
  on.step("the editor of atom {string} changes its param to {string}", (id: string, param: string) => {
    let (onChange, _) = editorOf(id)
    act(() => onChange({param: paramOf(param)}))
  })
  on.step("the editor of atom {string} changes its text to {string}", (id: string, text: string) => {
    let (onChange, _) = editorOf(id)
    act(() => onChange({text: text}))
  })
  on.step("the editor of atom {string} closes", (id: string) => {
    let (_, onClose) = editorOf(id)
    act(onClose)
  })

  on.step("the live atoms are", (table: array<array<string>>) => {
    let (state, _) = settled()
    let shownOf = (id: string) =>
      switch (state.live.atoms->Dict.get(id), state.live.live->Dict.get(id)) {
      | (Some({rule: "image"}), Some(value)) => shown(Obj.magic(value))
      | (Some(_), Some(value)) => (Obj.magic(value): Rule.atom).text
      | _ => "nothing"
      }
    let expected = toRecords(table)->Array.map((row: liveRow) => (row.atom, row.live))
    let ids = state.live.live->Dict.keysToArray->Array.toSorted(String.compare)
    expect(ids->Array.map(id => (id, shownOf(id)))).toEqual(
      expected->Array.toSorted(((a, _), (b, _)) => String.compare(a, b)),
    )
  })
  on.step("the live atoms are empty", () => {
    let (state, _) = settled()
    expect(state.live.live->Dict.keysToArray).toEqual([])
  })
  on.step("the loader has run", (table: array<array<string>>) => {
    ignore(settled())
    expect(runs).toEqual(
      toRecords(table)->Array.map((row: runRow): run => {
        atom: row.atom,
        source: row.source,
        previous: row.previous,
      }),
    )
  })
  on.step("the loader was called once for each atom", (table: array<array<string>>) => {
    ignore(settled())
    expect(runs->Array.map(run => run.atom)->Array.toSorted(String.compare)).toEqual(
      toRecords(table)->Array.map((row: idRow) => row.atom)->Array.toSorted(String.compare),
    )
  })

  on.step("the box holds atom {string}", (id: string) =>
    expect(doc().editing->Option.map(editing => editing.atom)).toEqual(Some(id))
  )
  on.step("the box is closed", () => expect(doc().editing).toEqual(None))
  on.step("no editor is open", () => {
    let (state, _) = settled()
    expect(state.editor).toEqual(None)
  })
  on.step("the editor of atom {string} is open", (id: string) => {
    let (state, _) = settled()
    expect(state.editor).toEqual(Some(id))
  })
  on.step("the caret is after atom {string}", (id: string) => {
    let doc = doc()
    let after = doc.blocks->Array.findMap(block =>
      block.content.marks
      ->Array.find(mark => mark.kind == Ref(id))
      ->Option.map(mark => {Doc.block: block.id, offset: mark.stop})
    )
    expect(doc.selection->Option.map(selection => (selection.anchor, selection.focus))).toEqual(
      after->Option.map(point => (point, point)),
    )
  })

  on.step("atom {string} draws {string}", (id: string, text: string) =>
    expect(drawn(id)->textContent).toBe(text)
  )
  on.step("atom {string} draws a placeholder", (id: string) => {
    let element = drawn(id)
    expect(element->querySelector(".image__placeholder")->Nullable.toOption->Option.isSome).toBe(
      true,
    )
    expect(element->querySelector("img")->Nullable.toOption).toEqual(None)
  })
  on.step("atom {string} draws an image described as {string}", (id: string, description: string) =>
    switch drawn(id)->querySelector("img")->Nullable.toOption {
    | Some(img) => expect(img->alt).toBe(description)
    | None => panic(`Atom ${id} draws no image`)
    }
  )
  on.step(
    "atom {string} draws an image {string} wide, described as {string}",
    (id: string, width: string, description: string) =>
      switch drawn(id)->querySelector("img")->Nullable.toOption {
      | Some(img) => expect((img->styleWidth, img->alt)).toEqual((width, description))
      | None => panic(`Atom ${id} draws no image`)
      },
  )

  on.step("the atoms are the same object", () => {
    let (state, _) = settled()
    same("atoms", Obj.magic(state.live.atoms))
  })
  on.step("atom {string} is the same object", (id: string) =>
    same("atom " ++ id, Obj.magic(atomOf(id)))
  )
  on.step("the param of atom {string} is the same object", (id: string) =>
    same("param " ++ id, Obj.magic(atomOf(id).param))
  )
  on.step("the param of atom {string} is {string}", (id: string, param: string) =>
    expect(sorted(atomOf(id).param)).toEqual(sorted(paramOf(param)))
  )
  on.step("the live atoms are the same object", () => {
    let (state, _) = settled()
    same("live", Obj.magic(state.live.live))
  })
  on.step("the live atom of {string} is the same object", (id: string) => {
    let (state, _) = settled()
    same("live " ++ id, Obj.magic(state.live.live->Dict.get(id)))
  })

  on.step("the typed text is", (table: array<array<string>>) => {
    let (state, _) = settled()
    expect(Typed.typed(state.live.typed).atoms).toEqual(atomsOf(table))
  })
  on.step("the port receives nothing", () => {
    ignore(settled())
    expect(received.contents).toEqual([])
  })
})
