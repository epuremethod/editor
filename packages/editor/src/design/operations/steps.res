open EpureVitest

// One `given` for every operation fixture: the document before, the act, and
// the document after, all three in the notation. Ids are compared only when
// the `after` names one, so a scenario about identity says so by writing it.
//
// An act is a word, with its argument in parentheses: `backspace`, `delete`,
// `enter`, `bold`, `link(/open-sets)`, `moveUp`, `paste(...)`,
// `embed(image, r42)`, `place(f2, width=50%)`,
// `input(For every ε| there is a δ.)`. The two arrows, `->` and `<-`, are
// acts too. Several acts make a list. The argument of `paste` is a document
// in the notation, one line per pasted block. The argument of `input` is one block as the browser left
// it: plain text and the selection, with no marks, since the browser knows
// none.

// An atom as a fixture writes it. An atom without a param has an empty one.
type given = {@as("type") type_: string, text: string, param?: dict<string>}

// `atoms` is the dictionary the document starts with, and `atomsAfter`
// what it holds after the acts; when absent, atoms are not compared.
type example = {
  before: string,
  @as("when") when_: JSON.t,
  after: string,
  atoms?: dict<given>,
  atomsAfter?: dict<given>,
}

let actLine = /^(\w+|->|<-)(?:\((.*)\))?$/s

// A new block takes the first letter no block holds, so an `after` written
// without ids reads a split as `a` then `b`.
let mintMany = (doc: Doc.t, count) => {
  let taken = doc.blocks->Array.map(block => block.id)
  let out = []
  let rec free = index => {
    let id = Notation.letter(index)
    taken->Array.includes(id) || out->Array.includes(id) ? free(index + 1) : id
  }
  for _ in 1 to count {
    out->Array.push(free(0))
  }
  out
}

let mint = (doc: Doc.t) => mintMany(doc, 1)->Array.getUnsafe(0)

// The harness's one rule for what enters: a type with a widget skips, and
// video is the type with a widget in the fixtures.
let enters: Edit.enters = atom => atom.type_ != "video"

// The atoms of a scenario, with the box's caret: a pipe in an atom's
// text is the caret, and the atom with it is the one being edited.
let atomsOf = (given: option<dict<given>>): (dict<Doc.atom>, option<Doc.editing>) => {
  let atoms = Dict.make()
  let editing = ref(None)
  given
  ->Option.getOr(Dict.make())
  ->Dict.forEachWithKey((given, id) => {
    let atom: Doc.atom = {
      type_: given.type_,
      text: given.text,
      param: given.param->Option.getOr(Dict.make()),
    }
    switch atom.text->String.indexOf("|") {
    | -1 => atoms->Dict.set(id, atom)
    | offset =>
      if editing.contents != None {
        panic("one atom at most holds the caret")
      }
      editing := Some({Doc.atom: id, offset})
      atoms->Dict.set(id, {...atom, text: atom.text->String.replace("|", "")})
    }
  })
  (atoms, editing.contents)
}

// A minted atom takes `e1`, `e2` and on, skipping ids the document holds.
let mintAtoms = (doc: Doc.t, count) => {
  let out = []
  let n = ref(1)
  while out->Array.length < count {
    let id = `e${Int.toString(n.contents)}`
    if !(doc.atoms->Dict.has(id)) {
      out->Array.push(id)
    }
    n := n.contents + 1
  }
  out
}

// An argument of two parts, parted by the first comma and space:
// `edit(a8f1, U \\in \\tau)`.
let twoParts = (argument: string, ~act) =>
  switch argument->String.indexOf(", ") {
  | -1 => panic(`${act} takes two arguments: ${act}(a, b)`)
  | at => (argument->String.slice(~start=0, ~end=at), argument->String.slice(~start=at + 2))
  }

// A param as an act writes it: `width=50%, rotate=90`.
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

let act = (doc: Doc.t, said: string) => {
  let (name, argument) = switch actLine->RegExp.exec(said->String.trim) {
  | Some(found) =>
    let matches = found->RegExp.Result.matches
    (matches->Array.getUnsafe(0)->Option.getOr(""), matches->Array.get(1)->Option.flatMap(x => x))
  | None => panic(`The act ${said} does not read as a word with an argument`)
  }
  switch (name, argument) {
  | ("backspace", None) => Edit.deleteBackward(doc)
  | ("delete", None) => Edit.deleteForward(doc)
  | ("heading", Some(level)) =>
    switch Int.fromString(level) {
    | Some(level) => Edit.form(doc, ~form=Heading(level))
    | None => panic("heading takes its level: heading(2)")
    }
  | ("paragraph", None) => Edit.form(doc, ~form=Paragraph)
  | ("item", None) => Edit.form(doc, ~form=Item)
  | ("display", None) => Edit.form(doc, ~form=Display)
  | ("edit", Some(argument)) =>
    let (id, text) = twoParts(argument, ~act="edit")
    Edit.edit(doc, ~id, ~text)
  | ("insert", Some(argument)) =>
    let (type_, text) = twoParts(argument, ~act="insert")
    Edit.insert(doc, ~id=mintAtoms(doc, 1)->Array.getUnsafe(0), ~type_, ~text)
  | ("embed", Some(argument)) =>
    let (type_, text) = twoParts(argument, ~act="embed")
    Edit.embed(doc, ~atom=mintAtoms(doc, 1)->Array.getUnsafe(0), ~block=mint(doc), ~type_, ~text)
  | ("place", Some(argument)) =>
    let (id, param) = twoParts(argument, ~act="place")
    Edit.place(doc, ~id, ~param=paramOf(param))
  | ("click", Some(block)) =>
    let {doc: placed} = Notation.read(block, ~plain=true)
    switch (doc.selection, placed.selection) {
    | (Some({focus: {block: id}}), Some({focus: {offset}})) =>
      Edit.select(doc, ~anchor={block: id, offset}, ~focus={block: id, offset})
    | (None, Some({focus: {offset}})) =>
      let id = (doc.blocks->Array.getUnsafe(0)).id
      Edit.select(doc, ~anchor={block: id, offset}, ~focus={block: id, offset})
    | _ => panic("click takes the block's plain text with the caret where the click lands")
    }
  | ("enter", None) => Edit.split(doc, ~id=mint(doc))
  | ("moveUp", None) => Edit.moveUp(doc)
  | ("moveDown", None) => Edit.moveDown(doc)
  | ("paste", Some(source)) =>
    let {doc: pasted} = Notation.read(source)
    let blocks = pasted.blocks->Array.map(block => block.content)
    let atomIds = mintAtoms(doc, Edit.adopted(doc, ~blocks)->Array.length)
    Edit.paste(doc, ~blocks, ~ids=mintMany(doc, blocks->Array.length - 1), ~atomIds)
  | ("->", None) => Edit.right(doc, ~enters)
  | ("<-", None) => Edit.left(doc, ~enters)
  | ("escape", None) => Edit.leave(doc)
  | ("bold", None) => Edit.toggle(doc, ~mark="bold")
  | ("italic", None) => Edit.toggle(doc, ~mark="italic")
  | ("code", None) => Edit.toggle(doc, ~mark="code")
  | ("link", Some(href)) => Edit.link(doc, ~href)
  | ("input", Some(block)) =>
    let {doc: changed} = Notation.read(block, ~plain=true)
    switch (changed.blocks, changed.selection) {
    | ([{content: {text}}], Some({anchor, focus})) =>
      Edit.input(doc, ~text, ~anchor=anchor.offset, ~focus=focus.offset)
    | ([_], None) => panic("The argument of input holds a caret or a selection")
    | _ => panic("The argument of input is one block")
    }
  | ("input", None) =>
    panic("input takes the block as the browser left it: input(For every ε| there is a δ.)")
  | (other, _) => panic(`The act ${other} is not known`)
  }
}

let acts = (when_: JSON.t) =>
  switch when_ {
  | String(one) => [one]
  | Array(many) =>
    many->Array.map(item =>
      switch item {
      | String(one) => one
      | _ => panic("An act is a string")
      }
    )
  | _ => panic("`when` is an act or a list of acts")
  }

given1("an editor", (_on, example: example) => {
  let before = Notation.read(example.before)
  let after = Notation.read(example.after)
  let labels = after.labeled
  let (atoms, editing) = atomsOf(example.atoms)
  let start = {...before.doc, atoms, editing}
  let result = acts(example.when_)->Array.reduce(start, act)
  expect(Notation.write(result, ~labels)).toBe(Notation.write(after.doc, ~labels))
  switch example.atomsAfter {
  | Some(given) =>
    let (atoms, editing) = atomsOf(Some(given))
    expect(result.atoms).toEqual(atoms)
    expect(result.editing).toEqual(editing)
  | None => ()
  }
})
