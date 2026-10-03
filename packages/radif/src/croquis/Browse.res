open RadifDb.Data
open Radif.Query

// A small browser over the client's own database. The Account is the one
// node nothing points to, so every node the client holds hangs under it.
// The browser walks down the edges from there, one row an edge, and keeps
// the path in local storage so a reload opens where the person left. Every
// read goes through the binding, so the rows move as the client's do.

@val @scope("localStorage") external kept: string => Nullable.t<string> = "getItem"
@val @scope("localStorage") external keep: (string, string) => unit = "setItem"
let key = "radif-browse"

type node = {id: Radif.id, klass: option<Radif.id>, title: string, icon: array<Radif.Icon.layer>}
type row = {node: node, level: Radif.access}
type t = {
  actor: Radif.id,
  /** The ids walked down from the Account, the Account left out. */
  mutable ids: array<Radif.id>,
  path: array<node>,
  rows: array<row>,
}

let field = (entity: Radif.Entity.t, ~facet, ~field) =>
  entity->Dict.get(facet)->Option.flatMap(part => part->Dict.get(field))

let classOf = entity =>
  switch field(entity, ~facet=Radif.Root.entity, ~field=Radif.Root.Entity.klass) {
  | Some(String(id)) => Some(id)
  | _ => None
  }

let titleOf = entity =>
  switch field(entity, ~facet=Radif.Root.titled, ~field=Radif.Root.Titled.title) {
  | Some(String(title)) => Some(title)
  | _ => None
  }

let iconOf = entity =>
  switch field(entity, ~facet=Radif.Root.iconed, ~field=Radif.Root.Iconed.icon) {
  | Some(json) =>
    Radif.Entry.list(json)
    ->Option.getOr([])
    ->Array.filterMap(({id, value}) =>
      value->JSON.Decode.string->Option.map((value): Radif.entry<string> => {id, value})
    )
    ->Radif.Icon.layers
  | None => []
  }

let section = Radif.Root.section

// The roots the croquis meets, by name, for a class row the client does
// not hold.
let names = Dict.fromArray([
  (Radif.Root.account, "Account"),
  (Radif.Root.inbox, "Inbox"),
  (Radif.Root.author, "Author"),
  (Radif.Root.personal, "Personal"),
  (Radif.Root.domain, "Domain"),
  (Radif.Root.app, "App"),
  (Radif.Root.invitation, "Invitation"),
  (Radif.Root.klass, "Class"),
  (section, "Section"),
])

// Until the roots carry an Iconed part, the ones the croquis meets draw
// from here, in the stored format on the 100 grid.
let stroke = path => `primary stroke 10 ${path}`
let cube = [
  stroke("M50 12 88 31v38L50 88 12 69V31Z"),
  stroke("M12 31l38 19 38 -19"),
  stroke("M50 50v38"),
]
let drawings =
  [
    (
      Radif.Root.account,
      [
        stroke("M31 31a19 19 0 1 0 38 0a19 19 0 1 0 -38 0Z"),
        stroke("M16 91c0 -19 15 -28 34 -28s34 9 34 28"),
      ],
    ),
    (
      Radif.Root.personal,
      [stroke("M12 53 50 19l38 34"), stroke("M25 47V88h50V47"), stroke("M41 88V63h18v25")],
    ),
    (
      Radif.Root.inbox,
      [stroke("M12 59h22l6 13h20l6 -13h22"), stroke("M12 59v25h76V59"), stroke("M22 59 31 28h38l9 31")],
    ),
    (
      Radif.Root.domain,
      [
        stroke("M13 50a37 37 0 1 0 74 0a37 37 0 1 0 -74 0Z"),
        stroke("M34 50a16 37 0 1 0 32 0a16 37 0 1 0 -32 0Z"),
        stroke("M13 50h74"),
      ],
    ),
    (Radif.Root.author, [stroke("M19 81l6 -25 44 -44 19 19 -44 44Z"), stroke("M59 28 72 41")]),
    (Radif.Root.invitation, [stroke("M12 25h76v56H12Z"), stroke("M12 28l38 31 38 -31")]),
    (section, [stroke("M19 25h62M19 44h62M19 63h44M19 81h31")]),
    (Radif.Root.app, cube),
    (Radif.Root.klass, cube),
  ]
  ->Array.map(((klass, layers)) => (klass, layers->Array.filterMap(Radif.Icon.parse)))
  ->Dict.fromArray

let dot = ["primary fill M34 50a16 16 0 1 0 32 0a16 16 0 1 0 -32 0Z"]->Array.filterMap(Radif.Icon.parse)

// A row by its id, a draft's too, as the store holds it. `None` while it
// loads, and where the client does not hold it.
let row = (binding: RadifTilia.t, id) =>
  switch binding.load(Radif.one(Radif.klassOfId(Radif.Root.entity))->withDrafts->at(id)) {
  | Loaded({data}) => Some(Radif.pack(data))
  | _ => None
  }

// A class by its row: the title, and the icon it carries or the drawing
// the croquis keeps for it.
let klassOf = (binding, klass) => {
  let row = row(binding, klass)
  let name =
    row
    ->Option.flatMap(titleOf)
    ->Option.orElse(names->Dict.get(klass))
    ->Option.getOr("a class")
  let icon = switch row->Option.mapOr([], iconOf) {
  | [] => drawings->Dict.get(klass)->Option.getOr(dot)
  | layers => layers
  }
  (name, icon)
}

// A node: its own title and icon, or its class's.
let node = (binding, id) =>
  switch row(binding, id) {
  | Some(entity) =>
    let klass = classOf(entity)
    let (className, classIcon) = switch klass {
    | Some(klass) => klassOf(binding, klass)
    | None => ("a node", dot)
    }
    let icon = switch iconOf(entity) {
    | [] => classIcon
    | own => own
    }
    {id, klass, title: titleOf(entity)->Option.getOr(className), icon}
  | None => {id, klass: None, title: "not held", icon: dot}
  }

let edges = (binding: RadifTilia.t, from) =>
  switch binding.edges(Some(Edge.From(from))) {
  | Loaded({data}) => data
  | _ => []
  }

let last = path => path->Array.last->Option.getOrThrow

let show = (self: t, ids) => {
  self.ids = ids
  keep(key, JSON.stringifyAny(ids)->Option.getOr("[]"))
}

let descend = (self, row: row) =>
  show(self, [...self.path->Array.slice(~start=1)->Array.map(node => node.id), row.node.id])

let climb = (self, at) =>
  show(self, self.path->Array.slice(~start=1, ~end=at + 1)->Array.map(node => node.id))

// The path is the kept ids walked down from the Account: each id has to
// hang under the one before, so a path into rows since removed stops where
// it fails, and grows back while the edges load.
let make = (~actor, ~binding) => {
  let ids =
    kept(key)
    ->Nullable.toOption
    ->Option.flatMap(text =>
      try JSON.parseOrThrow(text)->JSON.Decode.array catch {
      | _ => None
      }
    )
    ->Option.getOr([])
    ->Array.filterMap(JSON.Decode.string)
  Tilia.carve(({derived}) => {
    actor,
    ids,
    path: derived(self => {
      let rec walk = (path, ids) =>
        switch ids->Array.get(0) {
        | Some(next) if edges(binding, last(path).id)->Array.some(edge => edge.to == next) =>
          walk([...path, node(binding, next)], ids->Array.slice(~start=1))
        | _ => path
        }
      walk([node(binding, actor)], self.ids)
    }),
    rows: derived(self =>
      edges(binding, last(self.path).id)->Array.map(edge => {
        node: node(binding, edge.to),
        level: edge.level,
      })
    ),
  })
}

// An id as two short groups of its base64: characters 8 and 9 are the
// minute at sixteen minute steps, so rows minted in one sitting read as
// one moment, and 12 to 15 are three random bytes, which tell rows apart.
// The tenant comes first only where it is not the Account's own.
@val external btoa: string => string = "btoa"
let tag = (self: t, id: Radif.id) => {
  let text = btoa(id)
  let tenant =
    Radif.tenant(id) == Radif.tenant(self.actor)
      ? ""
      : text->String.slice(~start=0, ~end=6) ++ "·"
  tenant ++ text->String.slice(~start=8, ~end=10) ++ "·" ++ text->String.slice(~start=12, ~end=16)
}

// An icon's layers on the 100 grid, as the board draws them: the path
// reaches the page only as `d`. The box reaches past the grid by a tenth
// on each side, so a stroke on the grid's edge is not cut.
module Drawn = {
  let colour = (role: Radif.Icon.role) =>
    switch role {
    | Primary => "var(--icon-primary)"
    | Secondary => "var(--icon-secondary)"
    }

  @react.component
  let make = (~layers: array<Radif.Icon.layer>, ~size: int) =>
    <svg
      className="icon"
      width={size->Int.toString}
      height={size->Int.toString}
      viewBox="-10 -10 120 120"
      ariaHidden=true>
      {layers
      ->Array.mapWithIndex((layer, index) =>
        switch layer {
        | Stroke({role, width, path}) =>
          <path
            key={index->Int.toString}
            d=path
            fill="none"
            stroke={colour(role)}
            strokeWidth={width->Float.toString}
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        | Fill({role, path}) => <path key={index->Int.toString} d=path fill={colour(role)} />
        }
      )
      ->React.array}
    </svg>
}

let levelIcon = level => Radif.Access.icon(level)->Array.filterMap(Radif.Icon.parse)

module View = {
  @react.component
  let make = (~browse: t) => {
    TiliaReact.useTilia()
    <section className="browse">
      <nav className="crumbs">
        {browse.path
        ->Array.mapWithIndex((node, at) =>
          <React.Fragment key=node.id>
            {at == 0 ? React.null : <span className="sep"> {React.string("›")} </span>}
            <button className="crumb" onClick={_ => climb(browse, at)}>
              <Drawn layers=node.icon size=16 />
              {React.string(node.title)}
            </button>
          </React.Fragment>
        )
        ->React.array}
      </nav>
      <ul className="rows">
        {browse.rows
        ->Array.map(row =>
          <li key=row.node.id onClick={_ => descend(browse, row)}>
            <Drawn layers=row.node.icon size=16 />
            <span className="title"> {React.string(row.node.title)} </span>
            <span className="sep"> {React.string("/")} </span>
            <span className="id"> {React.string(tag(browse, row.node.id))} </span>
            <span className="level" title={Radif.Access.name(row.level)}>
              <Drawn layers={levelIcon(row.level)} size=16 />
            </span>
          </li>
        )
        ->React.array}
        {browse.rows->Array.length == 0
          ? <li className="empty"> {React.string("nothing hangs under it")} </li>
          : React.null}
      </ul>
    </section>
  }
}

let style = `
  .browse { max-width: 46rem; padding: 0 2rem 3rem; color: var(--grey); font-size: 0.85rem;
    --icon-primary: currentColor; --icon-secondary: var(--red); }
  .browse .icon { flex: none; }
  .crumbs { display: flex; flex-wrap: wrap; align-items: center; gap: 0.35rem; border-top: 1px solid var(--faint); padding-top: 0.5rem; }
  .crumb { display: inline-flex; align-items: center; gap: 0.35rem; border: none; padding: 0.1rem 0.3rem; color: var(--black); }
  .crumb:hover { background: var(--faint); color: var(--black); }
  .crumbs .sep { color: var(--grey); }
  .rows { list-style: none; padding: 0; margin: 0.5rem 0 0; }
  .rows li { display: flex; align-items: center; gap: 0.5rem; padding: 0.3rem 0.3rem; border-radius: 2px; cursor: pointer; }
  .rows li:hover { background: var(--faint); }
  .rows .title { color: var(--black); }
  .rows .id { font-family: "IBM Plex Mono", monospace; font-size: 0.8em; }
  .rows .level { display: inline-flex; margin-left: auto; color: var(--black); }
  .rows .empty { color: var(--grey); cursor: default; }
  .rows .empty:hover { background: none; }
`
