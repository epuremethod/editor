// The section as the view holds it: the core's typed state, and one tilia
// object for each atom, written in place so that a change reaches only what
// reads the part that changed. Each atom has a live atom, which its rule
// loads through a tilia source.

open Editor

type t = {
  mutable typed: Typed.t,
  atoms: dict<Rule.atom>,
  live: dict<unknown>,
  rules: dict<Rule.t>,
}

let liveOf = (rule: Rule.t, atom: Rule.atom): unknown =>
  switch rule.loader {
  | Some(loader) => Tilia.source(rule.first(atom), (previous, set) => loader(atom, previous, set))
  | None => rule.first(atom)
  }

let hold = (live: t, id: string, atom: Rule.atom) =>
  switch live.rules->Dict.get(atom.rule) {
  | Some(rule) => live.live->Dict.set(id, liveOf(rule, atom))
  | None => live.live->Dict.delete(id)
  }

// A key whose value did not change is not written: tilia would notify its
// readers for nothing.
let merge = (held: dict<string>, param: dict<string>) => {
  held
  ->Dict.keysToArray
  ->Array.forEach(key =>
    if !(param->Dict.has(key)) {
      held->Dict.delete(key)
    }
  )
  param->Dict.forEachWithKey((value, key) =>
    if held->Dict.get(key) != Some(value) {
      held->Dict.set(key, value)
    }
  )
}

let sync = (live: t) =>
  Tilia.batch(() => {
    let atoms = live.typed.doc.atoms
    live.atoms
    ->Dict.keysToArray
    ->Array.forEach(id =>
      if !(atoms->Dict.has(id)) {
        live.atoms
        ->Dict.get(id)
        ->Option.forEach(held =>
          live.rules
          ->Dict.get(held.rule)
          ->Option.flatMap(rule => rule.leave)
          ->Option.forEach(leave => leave(held))
        )
        live.atoms->Dict.delete(id)
        live.live->Dict.delete(id)
      }
    )
    atoms->Dict.forEachWithKey((atom, id) =>
      switch live.atoms->Dict.get(id) {
      | Some(held) =>
        if held.text != atom.text {
          held.text = atom.text
        }
        merge(held.param, atom.param)
        if held.rule != atom.type_ {
          held.rule = atom.type_
          hold(live, id, held)
        }
      | None =>
        live.atoms->Dict.set(
          id,
          {id, rule: atom.type_, text: atom.text, param: Dict.copy(atom.param)},
        )
        live.atoms->Dict.get(id)->Option.forEach(held => hold(live, id, held))
      }
    )
  })

let make = (~row: Section.t, ~doc: Doc.t, ~rules: dict<Rule.t>): t => {
  let live = Tilia.tilia({
    typed: Typed.make(~row, ~doc),
    atoms: Dict.make(),
    live: Dict.make(),
    rules,
  })
  sync(live)
  live
}
