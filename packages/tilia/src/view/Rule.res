// What the host knows about one kind of atom: how its param reads, the
// live atom it starts from, how it loads, how it draws and, optionally, its
// own editor. An atom names its rule by the first line of its text.

// The atom as the editor holds it: one tilia object for each atom id,
// written in place by every change.
type atom = {id: string, mutable rule: string, mutable text: string, param: dict<string>}

type codec<'p> = {decode: dict<string> => 'p, encode: 'p => dict<string>}

// A change from a rule's editor: a new text, a new param that replaces the
// old one, or both.
type change = {text?: string, param?: dict<string>}

type rule<'a, 'p> = {
  param: codec<'p>,
  first: atom => 'a,
  // The setup of a tilia source: it runs again when a value it read
  // changes, and receives the previous live atom.
  loader?: (atom, 'a, 'a => unit) => unit,
  render: ('a, ~param: 'p, ~display: bool) => React.element,
  editor?: ('a, ~param: 'p, ~onChange: change => unit, ~onClose: unit => unit) => React.element,
  // Called when the atom's id leaves the section, to release what the
  // rule holds for it.
  leave?: atom => unit,
}

// A rule with its live atom and its param erased, so that one dict holds
// the rules of every kind.
type t = {
  first: atom => unknown,
  loader: option<(atom, unknown, unknown => unit) => unit>,
  draw: (atom, unknown, ~display: bool) => React.element,
  editor: option<
    (atom, unknown, ~onChange: change => unit, ~onClose: unit => unit) => React.element,
  >,
  leave: option<atom => unit>,
}

let make = (rule: rule<'a, 'p>): t => {
  first: atom => Obj.magic(rule.first(atom)),
  loader: rule.loader->Option.map(loader =>
    (atom, previous, set) => loader(atom, Obj.magic(previous), live => set(Obj.magic(live)))
  ),
  draw: (atom: atom, live, ~display) =>
    rule.render(Obj.magic(live), ~param=rule.param.decode(atom.param), ~display),
  editor: rule.editor->Option.map(editor =>
    (atom: atom, live, ~onChange, ~onClose) =>
      editor(Obj.magic(live), ~param=rule.param.decode(atom.param), ~onChange, ~onClose)
  ),
  leave: rule.leave,
}

// The param as it is, for a rule that reads it whole.
let raw: codec<dict<string>> = {decode: param => param, encode: param => param}
