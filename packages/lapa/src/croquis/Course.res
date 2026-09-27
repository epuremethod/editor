// lapa types — Course — AAAAAQHHVdn1sGphG1Knfw==
//
// Written by `lapa types` from the model this app roots. Every run writes
// it again, so an edit by hand does not survive: change the model.

Lapa.app([
  (
    "AAAAAQHHVdlmHXT6iac4qA==",
    "section",
    [
      ("AAAAAQHHVdmRXn/P8ik2AQ==", "atoms", "entries"),
      ("AAAAAQHHVdlALm79Jg4uaA==", "blocks", "entries"),
    ],
    ["Li4uLkVudGl0eS4uLi4uLg==", "Li4uLk5vZGUuLi4uLi4uLg==", "Li4uLlJlY29yZC4uLi4uLg=="],
  ),
])

module Section = {
  type part = {
    mutable atoms: array<Lapa.entry>,
    mutable blocks: array<Lapa.entry>,
  }

  type t = {
    entity: Lapa.Root.Entity.t,
    mutable section?: part,
    mutable titled: Lapa.Root.Titled.t,
    mutable dated?: Lapa.Root.Dated.t,
    mutable described?: Lapa.Root.Described.t,
    mutable owned?: Lapa.Root.Owned.t,
    _rest: Lapa.rest,
  }

  let klass: Lapa.klass<t, [< #section | #titled | #dated | #described | #owned]> = Lapa.klass(
    "section.class",
  )
  let atoms: Lapa.field<array<Lapa.entry>, Lapa.many, [> #section]> = Lapa.entries("section.atoms")
  let blocks: Lapa.field<array<Lapa.entry>, Lapa.many, [> #section]> = Lapa.entries(
    "section.blocks",
  )
  let all = Lapa.all(klass)
  let one = Lapa.one(klass)
  let from = Lapa.from(klass)
  external record: t => Lapa.record = "%identity"

  let make = (context, ~under, ~section=?, ~titled, ~dated=?, ~described=?, ~owned=?): t => {
    entity: Lapa.entity(context, klass, ~under),
    ?section,
    titled,
    ?dated,
    ?described,
    ?owned,
    _rest: Lapa.rest(),
  }
}
