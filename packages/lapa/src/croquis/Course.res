// The root `Section`, as the croquis reads and writes it. The Course app
// defines no class of its own, so `lapa types` has nothing to write here.

module Section = {
  type t = {
    entity: Lapa.Root.Entity.t,
    mutable section: Lapa.Root.Section.t,
    mutable ordered: Lapa.Root.Ordered.t,
    mutable titled?: Lapa.Root.Titled.t,
    mutable dated?: Lapa.Root.Dated.t,
    mutable described?: Lapa.Root.Described.t,
    mutable owned?: Lapa.Root.Owned.t,
    _rest: Lapa.rest,
  }

  let klass: Lapa.klass<
    t,
    [< #section | #ordered | #titled | #dated | #described | #owned],
  > = Lapa.klass("section.class")
  external record: t => Lapa.record = "%identity"

  let make = (context, ~under, ~section, ~ordered, ~titled=?, ~dated=?, ~described=?, ~owned=?): t => {
    entity: Lapa.entity(context, klass, ~under),
    section,
    ordered,
    ?titled,
    ?dated,
    ?described,
    ?owned,
    _rest: Lapa.rest(),
  }
}
