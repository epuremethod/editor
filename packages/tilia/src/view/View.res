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
  // The entry whose type's widget is open under its atom, if any. The
  // box is the model's state; a widget is the view's.
  mutable widget: option<Doc.id>,
}

// The state of an editor over a section, a tilia tree the view observes.
let prepare = (section: Section.t): state =>
  Tilia.tilia({doc: Storage.read(section), revisions: Dict.make(), composing: false, widget: None})

let bump = (state: state, id: Doc.id) =>
  state.revisions->Dict.set(id, state.revisions->Dict.get(id)->Option.getOr(0) + 1)

// Replaces the document outright, every block rebuilt. For a host that
// swaps the section, and for a test that loads a scenario.
let load = (state: state, doc: Doc.t) => {
  doc.blocks->Array.forEach(block => bump(state, block.id))
  state.widget = None
  state.doc = doc
}

// How an entry draws, by its type, inline or as a display.
type render = (Doc.entry, ~display: bool) => React.element

// A type's own editor, opened by a click on its atom and placed under it
// by the editor: it takes the entry, a way to change its text, and a way
// to close.
type widget = (
  ~entry: Doc.entry,
  ~onChange: string => unit,
  ~onClose: unit => unit,
) => React.element

// What the host knows about a type. A type with `render` alone enters the
// editor's box under the arrows and on a click. A type with a widget
// skips under the arrows and opens its widget on a click. `enter` set to
// false skips and opens nothing.
type spec = {render: render, enter?: bool, widget?: widget}

let plain: render = (entry, ~display as _) =>
  <span className="source"> {React.string(entry.text)} </span>

// The spec of an entry's type; a type the host did not name shows its
// source and enters.
let specOf = (types: dict<spec>, entry: Doc.entry) =>
  types->Dict.get(entry.type_)->Option.getOr({render: plain})

let entersOf = (types: dict<spec>): Edit.enters =>
  entry => {
    let spec = specOf(types, entry)
    spec.enter->Option.getOr(spec.widget->Option.isNone)
  }

// Floating UI positions the box under an atom, above it when there is no
// room, and shifted to stay on screen.
module Floating = {
  type middleware
  type placed = {x: float, y: float}
  type options = {placement: string, strategy: string, middleware: array<middleware>}
  @module("@floating-ui/dom") external offset: int => middleware = "offset"
  @module("@floating-ui/dom") external flip: unit => middleware = "flip"
  @module("@floating-ui/dom") external shift: unit => middleware = "shift"
  @module("@floating-ui/dom")
  external computePosition: (Dom.element, Dom.element, options) => promise<placed> =
    "computePosition"
}

// A floater: whatever it holds, placed under an atom by Floating UI.
module Floater = {
  @react.component
  let make = (~anchor: unit => option<Dom.element>, ~className: string, ~children) => {
    let floating = React.useRef(Nullable.null)
    let (placed, setPlaced) = React.useState(() => None)
    React.useLayoutEffectOnEveryRender(() => {
      switch (anchor(), floating.current->Nullable.toOption) {
      | (Some(atom), Some(box)) =>
        Floating.computePosition(
          atom,
          box,
          {
            placement: "bottom-start",
            strategy: "fixed",
            middleware: [Floating.offset(6), Floating.flip(), Floating.shift()],
          },
        )
        ->Promise.thenResolve(at =>
          if placed != Some((at.x, at.y)) {
            setPlaced(_ => Some((at.x, at.y)))
          }
        )
        ->ignore
      | _ => ()
      }
      None
    })
    let (x, y) = placed->Option.getOr((0., 0.))
    <div
      className
      ref={ReactDOM.Ref.domRef(floating)}
      style={{
        position: "fixed",
        left: Float.toString(x) ++ "px",
        top: Float.toString(y) ++ "px",
        // Opacity, not visibility: a hidden element cannot take the focus.
        opacity: placed == None ? "0" : "1",
      }}
      contentEditable=false
    >
      {children}
    </div>
  }
}

@set external selectionStart: (Dom.element, int) => unit = "selectionStart"
@set external selectionEnd: (Dom.element, int) => unit = "selectionEnd"
@get external selectionAt: Dom.element => int = "selectionStart"

// The box: the entry's source as plain text, with the model's caret in it.
// Every keystroke is an act on the entry, and the atom follows it live.
// The arrows are the model's, so the edges of the source are its to
// decide; Escape leaves after the atom.
module Box = {
  @react.component
  let make = (
    ~entry: Doc.entry,
    ~offset: int,
    ~onChange: (string, int) => unit,
    ~onKey: string => bool,
    ~onBlur: unit => unit,
  ) => {
    let source = React.useRef(Nullable.null)
    // Focus after every layout effect has run, so the editor's own effect,
    // which places its selection, does not take the focus back.
    React.useEffect0(() => {
      source.current->Nullable.toOption->Option.forEach(Browser.focus)
      None
    })
    // The caret follows the model after every render.
    React.useLayoutEffectOnEveryRender(() => {
      source.current
      ->Nullable.toOption
      ->Option.forEach(node =>
        if node->selectionAt != offset {
          node->selectionStart(offset)
          node->selectionEnd(offset)
        }
      )
      None
    })
    <textarea
      className="box__source"
      ref={ReactDOM.Ref.domRef(source)}
      value=entry.text
      rows=1
      onChange={event => {
        let node = ReactEvent.Form.target(event)
        onChange(node["value"], node["selectionStart"])
      }}
      onKeyDown={event => {
        let plain =
          !(event->ReactEvent.Keyboard.shiftKey) &&
          !(event->ReactEvent.Keyboard.altKey) &&
          !(event->ReactEvent.Keyboard.metaKey) &&
          !(event->ReactEvent.Keyboard.ctrlKey)
        if plain && onKey(ReactEvent.Keyboard.key(event)) {
          ReactEvent.Keyboard.preventDefault(event)
        }
      }}
      onBlur={_ => onBlur()}
    />
  }
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
  | Ref(_) => inner
  }

// An atom: the entry a reference names, drawn by its type, and never edited
// by the browser. `data-atom` holds the reference's characters, so the atom
// counts as them. A reference to no entry draws as a placeholder. A mouse
// down opens the box.
module Atom = {
  @react.component
  let make = (
    ~id: Doc.id,
    ~text: string,
    ~entry: option<Doc.entry>,
    ~display: bool,
    ~render: render,
    ~onOpen: Doc.id => unit,
  ) => {
    let drawn = switch entry {
    | Some(entry) => render(entry, ~display)
    | None => <span className="atom__missing"> {React.string(text)} </span>
    }
    // The data attributes are set on the node: JSX types no `data-` prop.
    let tagged = ReactDOM.Ref.callbackDomRef(node => {
      node
      ->Nullable.toOption
      ->Option.forEach(node => {
        node->Browser.setAttribute("data-atom", text)
        node->Browser.setAttribute("data-ref", id)
      })
      None
    })
    // A zero-width space on each side: Chrome's scaffolding for a caret
    // beside an atom, which the browser bindings count as nothing.
    <>
      {React.string(Browser.zwsp)}
      <span
        className={display ? "atom atom--display" : "atom"}
        contentEditable=false
        ref=tagged
        onMouseDown={event => {
          ReactEvent.Mouse.preventDefault(event)
          onOpen(id)
        }}
      >
        {drawn}
      </span>
      {React.string(Browser.zwsp)}
    </>
  }
}

// One block, as the element its form calls for: a paragraph, a heading at
// its level, a list item, or a display holding its atom. The id on the
// element is what the selection resolves to.
module Block = {
  @react.component
  let make = (
    ~block: Doc.block,
    ~entries: dict<Doc.entry>,
    ~render: render,
    ~onOpen: Doc.id => unit,
  ) => {
    let pieces = Runs.segments(block.content)
    let id = "block-" ++ block.id
    let inner =
      pieces->Array.length == 0
        ? <br />
        : pieces
          ->Array.mapWithIndex(((text, kinds), index) => {
            let reference = kinds->Array.findMap(kind =>
              switch kind {
              | Ref(id) => Some(id)
              | _ => None
              }
            )
            let core = switch reference {
            | Some(ref) =>
              <Atom
                id=ref
                text
                entry={entries->Dict.get(ref)}
                display={block.form == Display}
                render
                onOpen
              />
            | None => React.string(text)
            }
            <React.Fragment key={Int.toString(index)}>
              {kinds->Array.toReversed->Array.reduce(core, (inner, kind) => wrap(kind, inner))}
            </React.Fragment>
          })
          ->React.array
    switch block.form {
    | Paragraph => <p id> {inner} </p>
    | Heading(1) => <h1 id> {inner} </h1>
    | Heading(2) => <h2 id> {inner} </h2>
    | Heading(_) => <h3 id> {inner} </h3>
    | Item => <li id> {inner} </li>
    | Display => <p id className="display"> {inner} </p>
    }
  }
}

// Whether the caret sits right after an atom, or right before one.
let besideAtom = (doc: Doc.t, ~after) =>
  switch doc.selection {
  | Some({anchor, focus}) if anchor == focus =>
    Doc.block(doc, focus.block)
    ->Option.flatMap(block =>
      after
        ? Runs.refEnding(block.content, focus.offset)
        : Runs.refStarting(block.content, focus.offset)
    )
    ->Option.isSome
  | _ => false
  }

// Whether a selection inside one block covers part of an atom.
let overAtom = (doc: Doc.t) =>
  switch doc.selection {
  | Some({anchor, focus}) if anchor != focus && anchor.block == focus.block =>
    Doc.block(doc, focus.block)
    ->Option.map(block => {
      let (from, to) =
        anchor.offset < focus.offset ? (anchor.offset, focus.offset) : (focus.offset, anchor.offset)
      block.content.marks->Array.some(mark =>
        Runs.isRef(mark.kind) && mark.start < to && mark.stop > from
      )
    })
    ->Option.getOr(false)
  | _ => false
  }

// The blocks in order, consecutive items gathered into one list.
let grouped = (blocks: array<Doc.block>): array<array<Doc.block>> => {
  let out: array<array<Doc.block>> = []
  blocks->Array.forEach(block => {
    switch (block.form, out->Array.get(out->Array.length - 1)) {
    | (Item, Some(group)) if (group->Array.getUnsafe(0)).form == Item => group->Array.push(block)
    | _ => out->Array.push([block])
    }
  })
  out
}

@react.component
let make = (
  ~state: state,
  ~section: Section.t,
  ~storage: Section.storage,
  ~mint: unit => string=mint,
  ~mintEntry: unit => string=mint,
  ~types: dict<spec>=Dict.make(),
) => {
  TiliaReact.useTilia()
  let root = React.useRef(Nullable.null)
  let enters = entersOf(types)
  let render: render = (entry, ~display) => specOf(types, entry).render(entry, ~display)

  // Applies an act. A block whose content changed is rebuilt, and so is a
  // block whose atom's entry changed. The section goes to the host when
  // any content or entry changed.
  let apply = (act: Doc.t => Doc.t) => {
    let before = state.doc
    let after = act(before)
    let changedEntries =
      after.entries
      ->Dict.toArray
      ->Array.filterMap(((id, entry)) =>
        before.entries->Dict.get(id) == Some(entry) ? None : Some(id)
      )
    let changed = after.blocks->Array.filter(block =>
      switch Doc.block(before, block.id) {
      | Some(old) =>
        old.content != block.content ||
        old.form != block.form ||
        block.content.marks->Array.some(mark =>
          switch mark.kind {
          | Ref(id) => changedEntries->Array.includes(id)
          | _ => false
          }
        )
      | None => true
      }
    )
    changed->Array.forEach(block => bump(state, block.id))
    state.doc = after
    if (
      changed->Array.length > 0 ||
      after.blocks->Array.length != before.blocks->Array.length ||
      after.entries != before.entries
    ) {
      storage.update([Storage.write(after, ~id=section.id)])
    }
  }

  // A click on an atom: the caret lands after the atom, and then the type
  // decides. A type that enters opens the box at the end of the source; a
  // type with a widget opens the widget; a type that neither enters nor
  // has a widget opens nothing.
  let open_ = (id: Doc.id) => {
    state.doc.blocks->Array.forEach(block =>
      block.content.marks->Array.forEach(mark =>
        if mark.kind == Ref(id) {
          let point = {Doc.block: block.id, offset: mark.stop}
          apply(doc => Edit.select(doc, ~anchor=point, ~focus=point))
        }
      )
    )
    switch state.doc.entries->Dict.get(id) {
    | Some(entry) =>
      let spec = specOf(types, entry)
      if spec.widget->Option.isSome {
        state.widget = Some(id)
      } else if enters(entry) {
        apply(doc => Edit.enter(doc, ~id))
      }
    | None => ()
    }
  }

  let focusRoot = () => root.current->Nullable.toOption->Option.forEach(Browser.focus)

  // Leaves the box by an act and gives the editor back its caret.
  let leaveBy = (act: Doc.t => Doc.t) => {
    apply(act)
    if state.doc.editing == None {
      focusRoot()
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
          ->Option.map(((block, _)) => Browser.plainText(block))
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
    | "deleteContentBackward"
      if across(doc) ||
      caretAt(doc, ~atStart=true) ||
      besideAtom(doc, ~after=true) ||
      overAtom(doc) =>
      prevent()
      apply(Edit.deleteBackward)
    | "deleteContentForward"
      if across(doc) ||
      caretAt(doc, ~atStart=false) ||
      besideAtom(doc, ~after=false) ||
      overAtom(doc) =>
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
      apply(doc => {
        let entryIds = Edit.adopted(doc, ~blocks)->Array.map(_ => mintEntry())
        Edit.paste(doc, ~blocks, ~ids, ~entryIds)
      })
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
      apply(doc => Edit.right(doc, ~enters))
    | "ArrowLeft" if plain && !across(state.doc) =>
      event->ReactEvent.Keyboard.preventDefault
      apply(doc => Edit.left(doc, ~enters))
    | "b" if command =>
      event->ReactEvent.Keyboard.preventDefault
      apply(doc => Edit.toggle(doc, ~mark="bold"))
    | "i" if command =>
      event->ReactEvent.Keyboard.preventDefault
      apply(doc => Edit.toggle(doc, ~mark="italic"))
    | "e" if command =>
      event->ReactEvent.Keyboard.preventDefault
      apply(doc => Edit.toggle(doc, ~mark="code"))
    // Cmd+M inserts a formula at the caret and opens its box.
    | "m" if command =>
      event->ReactEvent.Keyboard.preventDefault
      let id = mintEntry()
      apply(doc => Edit.insert(doc, ~id, ~type_="math", ~text="")->Edit.enter(~id, ~offset=0))
    | "ArrowUp" if command && event->ReactEvent.Keyboard.shiftKey =>
      event->ReactEvent.Keyboard.preventDefault
      apply(Edit.moveUp)
    | "ArrowDown" if command && event->ReactEvent.Keyboard.shiftKey =>
      event->ReactEvent.Keyboard.preventDefault
      apply(Edit.moveDown)
    // The forms go by key code: with Alt held, a digit's key is a symbol.
    | _ if command && event->ReactEvent.Keyboard.altKey =>
      let form = switch event->ReactEvent.Keyboard.code {
      | "Digit0" => Some(Doc.Paragraph)
      | "Digit1" => Some(Heading(1))
      | "Digit2" => Some(Heading(2))
      | "Digit3" => Some(Heading(3))
      | "Digit4" => Some(Display)
      | _ => None
      }
      form->Option.forEach(form => {
        event->ReactEvent.Keyboard.preventDefault
        apply(doc => Edit.form(doc, ~form))
      })
    | _
      if command &&
      event->ReactEvent.Keyboard.shiftKey &&
      event->ReactEvent.Keyboard.code == "Digit8" =>
      event->ReactEvent.Keyboard.preventDefault
      apply(doc => Edit.form(doc, ~form=Item))
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
      // The block's element, wherever it sits under the root: an item is
      // inside its list.
      let at = (point: Doc.point) =>
        root
        ->Browser.query("#block-" ++ point.block)
        ->Nullable.toOption
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

  let anchorOf = (id: Doc.id) =>
    () =>
      root.current
      ->Nullable.toOption
      ->Option.flatMap(root => root->Browser.query(`[data-ref="${id}"]`)->Nullable.toOption)

  let box = switch state.doc.editing {
  | Some({entry: id, offset}) =>
    switch state.doc.entries->Dict.get(id) {
    | Some(entry) =>
      <Floater key=id anchor={anchorOf(id)} className="box">
        <Box
          entry
          offset
          onChange={(text, offset) => apply(doc => Edit.edit(doc, ~id, ~text, ~offset))}
          onKey={key =>
            switch key {
            | "ArrowRight" =>
              leaveBy(doc => Edit.right(doc, ~enters))
              true
            | "ArrowLeft" =>
              leaveBy(doc => Edit.left(doc, ~enters))
              true
            | "Escape" =>
              leaveBy(doc => Edit.leave(doc))
              true
            | _ => false
            }}
          onBlur={() =>
            // The focus went elsewhere: the box closes and the caret stays.
            if state.doc.editing != None {
              apply(doc => {...doc, editing: None})
            }}
        />
      </Floater>
    | None => React.null
    }
  | None => React.null
  }

  let widget = switch state.widget {
  | Some(id) =>
    switch state.doc.entries
    ->Dict.get(id)
    ->Option.flatMap(entry => specOf(types, entry).widget->Option.map(widget => (entry, widget))) {
    | Some((entry, widget)) =>
      <Floater key=id anchor={anchorOf(id)} className="widget">
        {widget(
          ~entry,
          ~onChange=text => apply(doc => Edit.edit(doc, ~id, ~text)),
          ~onClose=() => {
            state.widget = None
            focusRoot()
          },
        )}
      </Floater>
    | None => React.null
    }
  | None => React.null
  }

  // `pre-wrap` keeps every space as typed: without it Chrome drops a space it
  // deems collapsed while editing, and the model's diff sees a replacement
  // where a letter was inserted.
  // The box comes after the editor: React attaches refs in tree order, and
  // the box finds its atom by one.
  <>
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
      {grouped(state.doc.blocks)
      ->Array.map(group => {
        let drawn =
          group
          ->Array.map(block =>
            <Block
              key={block.id ++
              ":" ++
              Int.toString(state.revisions->Dict.get(block.id)->Option.getOr(0))}
              block
              entries=state.doc.entries
              render
              onOpen=open_
            />
          )
          ->React.array
        (group->Array.getUnsafe(0)).form == Item
          ? <ul key={"list-" ++ (group->Array.getUnsafe(0)).id}> {drawn} </ul>
          : drawn
      })
      ->React.array}
    </div>
    {box}
    {widget}
  </>
}
