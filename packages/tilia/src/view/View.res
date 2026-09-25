// The editor over one section: React over contentEditable, with the model
// as the only source of truth. The browser edits text inside a block and
// the model reads it back; every structural act is intercepted and applied
// to the model, and the block whose content changed is rebuilt from it.

open Editor

type state = {
  mutable doc: Doc.t,
  // Bumped for a block whose content changed, so React rebuilds its DOM
  // instead of patching what the browser already touched.
  mutable revisions: dict<int>,
  mutable composing: bool,
}

// The state of an editor over a section, a tilia tree the view observes.
let prepare = (section: Section.t): state =>
  Tilia.tilia({doc: Storage.read(section), revisions: Dict.make(), composing: false})

// Replaces the document outright, every block rebuilt. For a host that
// swaps the section, and for a test that loads a scenario.
let load = (state: state, doc: Doc.t) => {
  doc.blocks->Array.forEach(block =>
    state.revisions->Dict.set(block.id, state.revisions->Dict.get(block.id)->Option.getOr(0) + 1)
  )
  state.doc = doc
}

let mint = () => {
  let stamp = Date.now()->Float.toString
  `b${stamp->String.slice(~start=-6)}${(Math.random() *. 1000.)->Float.toInt->Int.toString}`
}

// The block element holding a node and its id. A text node has no
// `closest`, so the climb starts at its parent.
let blockId = (node: Browser.node) =>
  (Browser.isText(node) ? node->Browser.parent->Nullable.toOption : Some(node))
  ->Option.flatMap(element => element->Browser.closest("[id^='block-']")->Nullable.toOption)
  ->Nullable.fromOption
  ->Nullable.toOption
  ->Option.flatMap(block =>
    block
    ->Browser.attribute("id")
    ->Nullable.toOption
    ->Option.map(id => (block, id->String.slice(~start=6)))
  )

// The DOM selection as two model points, when it sits inside the editor.
let selected = (root: Browser.node): option<(Doc.point, Doc.point)> =>
  switch Browser.selected()->Nullable.toOption {
  | None => None
  | Some(selection) =>
    let point = (node, offset) =>
      node
      ->Nullable.toOption
      ->Option.filter(node => root->Browser.contains(node))
      ->Option.flatMap(blockId)
      ->Option.map(((block, id)) => {
        Doc.block: id,
        offset: Browser.offsetOf(block, node->Nullable.getUnsafe, offset),
      })
    switch (
      point(selection->Browser.anchorNode, selection->Browser.anchorOffset),
      point(selection->Browser.focusNode, selection->Browser.focusOffset),
    ) {
    | (Some(anchor), Some(focus)) => Some((anchor, focus))
    | _ => None
    }
  }

let same = (a: option<(Doc.point, Doc.point)>, selection: option<Doc.selection>) =>
  switch (a, selection) {
  | (Some((anchor, focus)), Some(model)) => anchor == model.anchor && focus == model.focus
  | (None, None) => true
  | _ => false
  }

let across = (doc: Doc.t) =>
  switch doc.selection {
  | Some({anchor, focus}) => anchor.block != focus.block
  | None => false
  }

let caretAt = (doc: Doc.t, ~atStart) =>
  switch doc.selection {
  | Some({anchor, focus}) if anchor == focus =>
    atStart
      ? focus.offset == 0
      : Doc.block(doc, focus.block)
        ->Option.map(block => focus.offset == block.content.text->String.length)
        ->Option.getOr(false)
  | _ => false
  }

let wrap = (kind: Doc.kind, inner: React.element) =>
  switch kind {
  | Bold => <strong> {inner} </strong>
  | Italic => <em> {inner} </em>
  | Code => <code> {inner} </code>
  | Link(href) => <a href> {inner} </a>
  }

module Block = {
  @react.component
  let make = (~block: Doc.block) => {
    let pieces = Runs.segments(block.content)
    <p id={"block-" ++ block.id}>
      {pieces->Array.length == 0
        ? <br />
        : pieces
          ->Array.mapWithIndex(((text, kinds), index) =>
            <React.Fragment key={Int.toString(index)}>
              {kinds
              ->Array.toReversed
              ->Array.reduce(React.string(text), (inner, kind) => wrap(kind, inner))}
            </React.Fragment>
          )
          ->React.array}
    </p>
  }
}

@react.component
let make = (
  ~state: state,
  ~section: Section.t,
  ~storage: Section.storage,
  ~mint: unit => string=mint,
) => {
  TiliaReact.useTilia()
  let root = React.useRef(Nullable.null)

  // Applies an act. A block whose content changed is rebuilt, and the
  // section goes to the host when any content changed.
  let apply = (act: Doc.t => Doc.t) => {
    let before = state.doc
    let after = act(before)
    let changed = after.blocks->Array.filter(block =>
      switch Doc.block(before, block.id) {
      | Some(old) => old.content != block.content
      | None => true
      }
    )
    changed->Array.forEach(block =>
      state.revisions->Dict.set(block.id, state.revisions->Dict.get(block.id)->Option.getOr(0) + 1)
    )
    state.doc = after
    if changed->Array.length > 0 || after.blocks->Array.length != before.blocks->Array.length {
      storage.update([Storage.write(after, ~id=section.id)])
    }
  }

  // Reads the focused block back, as the browser left it.
  let readBack = () =>
    root.current
    ->Nullable.toOption
    ->Option.flatMap(selected)
    ->Option.forEach(((anchor, focus)) =>
      if anchor.block == focus.block {
        let text =
          Browser.selected()
          ->Nullable.toOption
          ->Option.flatMap(s => s->Browser.focusNode->Nullable.toOption)
          ->Option.flatMap(blockId)
          ->Option.map(((block, _)) => Browser.textContent(block))
          ->Option.getOr("")
        // The model keeps the caret from before the edit: it bounds the
        // diff, and the marks a typed letter takes hang on it. The DOM's
        // caret is where the edit leaves it.
        apply(doc => Edit.input(doc, ~text, ~anchor=anchor.offset, ~focus=focus.offset))
      }
    )

  // The model's selection, brought level with the DOM's. A key can arrive
  // before `selectionchange` has, so every handler starts here.
  let sync = () =>
    root.current
    ->Nullable.toOption
    ->Option.flatMap(selected)
    ->Option.forEach(((anchor, focus)) =>
      if !same(Some((anchor, focus)), state.doc.selection) {
        apply(doc => Edit.select(doc, ~anchor, ~focus))
      }
    )

  let onBeforeInput = (event: Browser.event) => {
    sync()
    let doc = state.doc
    let prevent = () => event->Browser.prevent
    switch event->Browser.inputType {
    | "insertParagraph" =>
      prevent()
      apply(doc => Edit.split(doc, ~id=mint()))
    | "insertLineBreak" | "historyUndo" | "historyRedo" | "insertFromDrop" => prevent()
    | "deleteContentBackward" if across(doc) || caretAt(doc, ~atStart=true) =>
      prevent()
      apply(Edit.deleteBackward)
    | "deleteContentForward" if across(doc) || caretAt(doc, ~atStart=false) =>
      prevent()
      apply(Edit.deleteForward)
    | "formatBold" =>
      prevent()
      apply(doc => Edit.toggle(doc, ~mark="bold"))
    | "formatItalic" =>
      prevent()
      apply(doc => Edit.toggle(doc, ~mark="italic"))
    | "insertFromPaste" =>
      prevent()
      let text =
        event
        ->Browser.transfer
        ->Nullable.toOption
        ->Option.map(t => t->Browser.getData("text/plain"))
        ->Option.getOr("")
      let blocks =
        text->String.split("\n")->Array.map(line => Inline.read(line, ~notation=false).text)
      let ids = blocks->Array.slice(~start=1, ~end=blocks->Array.length)->Array.map(_ => mint())
      apply(doc => Edit.paste(doc, ~blocks, ~ids))
    | _ if across(doc) =>
      // A text-level edit over a selection across blocks: the range goes,
      // and what was typed lands in the joined block.
      prevent()
      apply(doc => {
        let joined = Edit.deleteBackward(doc)
        switch (event->Browser.data->Nullable.toOption, joined.selection) {
        | (Some(data), Some({focus, pending})) =>
          let block = Doc.block(joined, focus.block)->Option.getUnsafe
          let text =
            block.content.text->String.slice(~start=0, ~end=focus.offset) ++
            data ++
            block.content.text->String.slice(~start=focus.offset)
          pending->ignore
          Edit.input(
            joined,
            ~text,
            ~anchor=focus.offset + data->String.length,
            ~focus=focus.offset + data->String.length,
          )
        | _ => joined
        }
      })
    | _ => ()
    }
  }

  let onInput = (event: Browser.event) =>
    if !(event->Browser.composing) && !state.composing {
      readBack()
    }

  let onKeyDown = (event: ReactEvent.Keyboard.t) => {
    sync()
    let plain =
      !(event->ReactEvent.Keyboard.shiftKey) &&
      !(event->ReactEvent.Keyboard.altKey) &&
      !(event->ReactEvent.Keyboard.metaKey) &&
      !(event->ReactEvent.Keyboard.ctrlKey)
    let command = event->ReactEvent.Keyboard.metaKey || event->ReactEvent.Keyboard.ctrlKey
    switch event->ReactEvent.Keyboard.key {
    | "ArrowRight" if plain && !across(state.doc) =>
      event->ReactEvent.Keyboard.preventDefault
      apply(Edit.right)
    | "ArrowLeft" if plain && !across(state.doc) =>
      event->ReactEvent.Keyboard.preventDefault
      apply(Edit.left)
    | "b" if command =>
      event->ReactEvent.Keyboard.preventDefault
      apply(doc => Edit.toggle(doc, ~mark="bold"))
    | "i" if command =>
      event->ReactEvent.Keyboard.preventDefault
      apply(doc => Edit.toggle(doc, ~mark="italic"))
    | "e" if command =>
      event->ReactEvent.Keyboard.preventDefault
      apply(doc => Edit.toggle(doc, ~mark="code"))
    | "ArrowUp" if command && event->ReactEvent.Keyboard.shiftKey =>
      event->ReactEvent.Keyboard.preventDefault
      apply(Edit.moveUp)
    | "ArrowDown" if command && event->ReactEvent.Keyboard.shiftKey =>
      event->ReactEvent.Keyboard.preventDefault
      apply(Edit.moveDown)
    | _ => ()
    }
  }

  // The native listeners: `beforeinput` has no faithful React event.
  React.useEffect0(() => {
    switch root.current->Nullable.toOption {
    | None => None
    | Some(node) =>
      node->Browser.on("beforeinput", onBeforeInput)
      node->Browser.on("input", onInput)
      let onSelection = _ =>
        switch root.current->Nullable.toOption {
        | Some(root) if !state.composing =>
          let now = selected(root)
          switch now {
          | Some((anchor, focus)) if !same(now, state.doc.selection) =>
            apply(doc => Edit.select(doc, ~anchor, ~focus))
          | _ => ()
          }
        | _ => ()
        }
      Browser.listen("selectionchange", onSelection)
      Some(
        () => {
          node->Browser.off("beforeinput", onBeforeInput)
          node->Browser.off("input", onInput)
          Browser.unlisten("selectionchange", onSelection)
        },
      )
    }
  })

  // After every render the DOM selection follows the model, while the
  // editor holds the focus.
  React.useLayoutEffectOnEveryRender(() => {
    switch (
      root.current->Nullable.toOption,
      state.doc.selection,
      Browser.selected()->Nullable.toOption,
    ) {
    | (Some(root), Some({anchor, focus}), Some(selection))
      if Browser.active
      ->Nullable.toOption
      ->Option.map(active => active === root)
      ->Option.getOr(false) =>
      let at = (point: Doc.point) =>
        root
        ->Browser.children
        ->Browser.listed
        ->Array.find(block =>
          block->Browser.attribute("id")->Nullable.toOption == Some("block-" ++ point.block)
        )
        ->Option.map(block => Browser.pointAt(block, point.offset))
      switch (at(anchor), at(focus)) {
      | (Some((a, ao)), Some((f, fo))) =>
        if !same(selected(root), Some({anchor, focus, pending: []})) {
          selection->Browser.place(a, ao, f, fo)
        }
      | _ => ()
      }
    | _ => ()
    }
    None
  })

  // `pre-wrap` keeps every space as typed: without it Chrome drops a space it
  // deems collapsed while editing, and the model's diff sees a replacement
  // where a letter was inserted.
  <div
    className="editor"
    style={{whiteSpace: "pre-wrap"}}
    ref={ReactDOM.Ref.domRef(root)}
    contentEditable=true
    suppressContentEditableWarning=true
    onKeyDown
    onCompositionStart={_ => state.composing = true}
    onCompositionEnd={_ => {
      state.composing = false
      readBack()
    }}
  >
    {state.doc.blocks
    ->Array.map(block =>
      <Block
        key={block.id ++ ":" ++ Int.toString(state.revisions->Dict.get(block.id)->Option.getOr(0))}
        block
      />
    )
    ->React.array}
  </div>
}
