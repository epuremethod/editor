open EpureVitest

// One `given` for every operation fixture: the document before, the act, and
// the document after, all three in the notation. Ids are compared only when
// the `after` names one, so a scenario about identity says so by writing it.
//
// An act is a word, with its argument in parentheses: `backspace`, `delete`,
// `enter`, `bold`, `link(/open-sets)`, `moveUp`, `paste(...)`,
// `input(For every ε| there is a δ.)`. The two arrows, `->` and `<-`, are
// acts too. Several acts make a list. The argument of `paste` is a document
// in the notation, one line per pasted block. The argument of `input` is one block as the browser left
// it: plain text and the selection, with no marks, since the browser knows
// none.

type example = {before: string, @as("when") when_: JSON.t, after: string}

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
    Edit.paste(doc, ~blocks, ~ids=mintMany(doc, blocks->Array.length - 1))
  | ("->", None) => Edit.right(doc)
  | ("<-", None) => Edit.left(doc)
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
  let result = acts(example.when_)->Array.reduce(before.doc, act)
  expect(Notation.write(result, ~labels)).toBe(Notation.write(after.doc, ~labels))
})
