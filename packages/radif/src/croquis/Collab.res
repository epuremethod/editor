open RadifDb.App
open RadifDb.Data
open Radif.Query
open Editor

// Two people, one document: the croquis. The page opens a radif client on
// the session in its address and mounts today's `@tilia/editor` over the
// document's first section. The founder finds or makes the document under
// their Personal node, with one section attached to it, and invites every
// other member to edit the document. A member joins with the admission code
// in the address, waits for the offer, accepts it onto their Personal node,
// and edits the same section. Every read goes through `@radif/tilia`, rows
// and edges, so what the page shows moves as the client's rows do: the
// documents under the person's Personal node are one live list, and the
// sections attached to its first are another. Every act writes a copy of the record; the binding
// folds what comes back, own write or other device, onto the live record,
// and a watch on it lands the fold on the blocks it changed, and on no
// other.

@val @scope(("window", "location")) external search: string = "search"
type params
@new external params: string => params = "URLSearchParams"
@send external asked: (params, string) => Nullable.t<string> = "get"

let session = params(search)->asked("radif-session")->Nullable.toOption
let code = params(search)->asked("radif-code")->Nullable.toOption

// The session stays in the address and never in local storage, so two tabs
// are two people. A redeemed code is spent, so the address takes the
// session it answered before the page opens on it.
@val @scope(("window", "history"))
external replaceState: (Nullable.t<string>, string, string) => unit = "replaceState"

let outcome = (run: Reply.outcome<'a> => unit): promise<'a> =>
  Promise.make((resolve, reject) =>
    run({ok: resolve, error: message => reject(JsError.make(message))})
  )

let listed = loadable =>
  switch loadable {
  | Radif.Loaded({data}) => data
  | _ => []
  }

let loaded = loadable =>
  switch loadable {
  | Radif.Loaded({data}) => Some(data)
  | _ => None
  }

// Where the person stands: the Domain their Account reads, at `admin` for
// the founder and `read` for a member, and their own Inbox and Personal
// node. The three are the nodes under the Account, each of its class.
// `None` while the reads load.
type standing = {domain: Radif.id, founder: bool, inbox: Radif.id, personal: Radif.id}

let standing = (binding: RadifTilia.t, ~account) => {
  let edges = binding.edges(Some(Edge.From(account)))
  let domains = binding.load(Radif.under(RadifStore.Domain.klass)(account))
  let inboxes = binding.load(Radif.under(RadifStore.Inbox.klass)(account))
  let personals = binding.load(Radif.under(RadifStore.Personal.klass)(account))
  switch (edges, domains, inboxes, personals) {
  | (Loaded({data: edges}), Loaded({data: domains}), Loaded({data: inboxes}), Loaded({data: personals})) =>
    switch (domains->Array.get(0), inboxes->Array.get(0), personals->Array.get(0)) {
    | (Some(domain), Some(inbox), Some(personal)) =>
      Some(
        Ok({
          domain: domain.entity.id,
          founder: edges->Array.some(edge =>
            edge.to == domain.entity.id && edge.level == Radif.Access.admin
          ),
          inbox: inbox.entity.id,
          personal: personal.entity.id,
        }),
      )
    | _ => Some(Error("the client reaches no Domain, Inbox or Personal node"))
    }
  | _ => None
  }
}

let opening: array<Radif.entry<string>> = [
  {id: "a", value: "# Open sets"},
  {
    id: "b",
    value: "A **topology** on a set X is a collection τ of subsets of X, called _open sets_, such that:",
  },
  {id: "c", value: "The empty set and X itself are open."},
  {
    id: "d",
    value: "Any union of open sets is open, and any finite intersection of open sets is open.",
  },
  {id: "e", value: "The pair {{f1}} is the first axiom, and alone it is a display:"},
  {id: "f", value: ":: {{f1}}"},
]

let openingAtoms: array<Radif.placed<string>> = [
  {
    id: "f1",
    value: "math\n\\emptyset \\in \\tau \\quad\\text{and}\\quad X \\in \\tau",
    param: Dict.make(),
  },
]

let save = (client: Client.t, section: RadifStore.Section.t) =>
  outcome(reply => client.upsert([RadifStore.Section.record(section)], reply))

// The founder's first document, under their Personal node, and its one
// section under it and attached to it.
let opened = (client: Client.t, standing: standing) => {
  let document = RadifStore.Document.make(
    client.context,
    ~under=standing.personal,
    ~document={extension: "course"},
    ~titled={title: "Open sets"},
  )
  let section = RadifStore.Section.make(
    client.context,
    ~under=document.entity.id,
    ~section={blocks: opening, atoms: openingAtoms},
    ~attached={parents: [{id: document.entity.id, value: "a", param: Dict.make()}]},
  )
  outcome(reply =>
    client.upsert(
      [RadifStore.Document.record(document), RadifStore.Section.record(section)],
      reply,
    )
  )
}

// The sections attached to a document, in their position under it.
let sections = (binding: RadifTilia.t, ~document: Radif.id) =>
  switch binding.load(RadifStore.Section.all->from(RadifStore.Attached.parents)->at(document)) {
  | Loaded({claim, data}) =>
    let position = (section: RadifStore.Section.t) =>
      section.attached.parents
      ->Array.find(parent => parent.id == document)
      ->Option.mapOr("", parent => parent.value)
    Radif.Loaded({
      claim,
      data: data->Array.toSorted((a, b) => String.compare(position(a), position(b))),
    })
  | other => other
  }

// ── the port ────────────────────────────────────────────────────────────

let port = (section: RadifStore.Section.t): Section.t => {
  id: section.entity.id,
  blocks: section.section.blocks->Array.map(entry => (entry.id, entry.value)),
  atoms: section.section.atoms->Array.map(({id, value, param}): Section.atom => {
    id,
    text: value,
    param,
  }),
}

let written = (section: RadifStore.Section.t, port: Section.t): RadifStore.Section.t => {
  ...section,
  section: {
    blocks: port.blocks->Array.map(((id, value)): Radif.entry<string> => {id, value}),
    atoms: port.atoms->Array.map(({id, text, param}): Radif.placed<string> => {
      id,
      value: text,
      param,
    }),
  },
}

// ── the types ───────────────────────────────────────────────────────────

type katexOptions = {displayMode: bool, throwOnError: bool}
@module("katex") external renderToString: (string, katexOptions) => string = "renderToString"

let math: TiliaEditor.View.render = (atom, ~display) =>
  <span
    className="math"
    dangerouslySetInnerHTML={{
      "__html": renderToString(atom.text, {displayMode: display, throwOnError: false}),
    }}
  />

let types: dict<TiliaEditor.View.spec> = Dict.fromArray([("math", {TiliaEditor.View.render: math})])

// ── the page ────────────────────────────────────────────────────────────

// Another member of the Domain, as the founder sees them: their Inbox, the
// name their Author carries, and where the offer of the document stands.
type other = {inbox: Radif.id, name: string, offered: option<Radif.access>}

type opened = {
  client: Client.t,
  standing: standing,
  /** The document the section is attached to: what the founder shares. */
  document: RadifStore.Document.t,
  state: TiliaEditor.View.state,
  /** The other members, read by the founder alone. */
  others: array<other>,
  /** The live record the binding hands out: every fold lands on it. */
  section: RadifStore.Section.t,
  mutable storage: Section.storage,
  mutable synced: bool,
  mutable saved: int,
  /** Deliveries naming the section. */
  mutable received: int,
  /** Blocks a delivery changed on screen. */
  mutable changed: int,
  /** Deliveries that met this device's own write still in its outbox: the
      client answers the outbox's row, so the fold changes nothing. */
  mutable skipped: int,
  /** The section as it was last written: the base a delivery is laid
      against, so a block changed here since then keeps the local text. */
  mutable base: Section.t,
  /** The latest section an act produced and nothing wrote yet. */
  mutable pending: option<Section.t>,
  /** The pause: restarted by every act, fires when the person stops. */
  mutable quiet: option<timeoutId>,
  /** The cap: started by the first unsaved change, restarted by nothing. */
  mutable cap: option<timeoutId>,
  /** Blocks a fold left alone because they had changed here since the
      last write. */
  mutable held: int,
}

// A save goes out when the person pauses for one second, and no later
// than one second after the first unsaved change, and at once when the
// page loses the person: blur, the tab hidden, the page going away.
let pause = 1_000
let atMost = 1_000

@val @scope("window") external onWindow: (string, unit => unit) => unit = "addEventListener"
@val @scope("document") external onDocument: (string, unit => unit) => unit = "addEventListener"
@val @scope("document") external hidden: bool = "hidden"

// ── the arrival ─────────────────────────────────────────────────────────

// A caret through the change from one text to the next: before the changed
// span it stays, after it it moves by the difference, inside it it lands at
// the span's start.
let mapped = (offset, ~old: string, ~new_: string) => {
  let oldLength = String.length(old)
  let prefix = Edit.commonPrefix(old, new_, ~max=oldLength)
  let suffix = Edit.commonSuffix(
    old,
    new_,
    ~max=Math.Int.min(oldLength, String.length(new_)) - prefix,
  )
  if offset <= prefix {
    offset
  } else if offset >= oldLength - suffix {
    offset + (String.length(new_) - oldLength)
  } else {
    prefix
  }
}

// The live record onto the view: a block whose text and form did not move
// keeps its object and its DOM, a block that did is rebuilt, and so is a
// block whose atom changed. A block changed here since the last write
// keeps the local text: what arrived is older than what the person typed,
// and the next write carries it. The caret follows its block's text.
// Answers how many blocks changed and how many were held.
let arrive = (state: TiliaEditor.View.state, section: RadifStore.Section.t, ~base: Section.t) => {
  let before = state.doc
  let fresh = Storage.read(port(section))
  let local = Storage.write(before, ~id=base.id).blocks->Dict.fromArray
  let written = base.blocks->Dict.fromArray
  let heldHere = id => local->Dict.get(id) != written->Dict.get(id)
  let held = []
  let changedAtoms =
    fresh.atoms
    ->Dict.toArray
    ->Array.filterMap(((id, atom)) => before.atoms->Dict.get(id) == Some(atom) ? None : Some(id))
  let changed = []
  let blocks = fresh.blocks->Array.map(block =>
    switch Doc.block(before, block.id) {
    | Some(old) if heldHere(block.id) =>
      held->Array.push(block.id)
      old
    | Some(old)
      if old.form == block.form &&
      old.content == block.content &&
      !(
        block.content.marks->Array.some(mark =>
          switch mark.kind {
          | Ref(id) => changedAtoms->Array.includes(id)
          | _ => false
          }
        )
      ) => old
    | _ =>
      changed->Array.push(block.id)
      block
    }
  )
  let point = (point: Doc.point): Doc.point =>
    switch (Doc.block(before, point.block), Doc.block(fresh, point.block)) {
    | (Some(old), Some(new_)) if changed->Array.includes(point.block) => {
        ...point,
        offset: mapped(point.offset, ~old=old.content.text, ~new_=new_.content.text),
      }
    | (_, Some(_)) => point
    | (_, None) =>
      // The block is gone: the caret lands at the start of the first one.
      switch fresh.blocks->Array.get(0) {
      | Some(first) => {block: first.id, offset: 0}
      | None => point
      }
    }
  let selection = before.selection->Option.map(selection => {
    ...selection,
    anchor: point(selection.anchor),
    focus: point(selection.focus),
  })
  changed->Array.forEach(id => TiliaEditor.View.bump(state, id))
  state.doc = {...before, blocks, atoms: fresh.atoms, selection}
  (changed->Array.length, held->Array.length)
}

// ── the people ──────────────────────────────────────────────────────────

// The other members, read off the Domain: every Inbox under it, but the
// person's own, named by the Author who owns it, and the level the offer of
// the document stands at, where one runs. An accepted offer moves onto the
// member's Personal node, which the founder does not reach, so from here
// an acceptance and no offer read the same: the founder's store cannot say
// who edits the document.
let others = (binding: RadifTilia.t, standing: standing, ~document: Radif.id) => {
  let offers = binding.edges(Some(Edge.To(document)))->listed
  binding.load(Radif.under(RadifStore.Inbox.klass)(standing.domain))
  ->listed
  ->Array.filter(inbox => inbox.entity.id != standing.inbox)
  ->Array.filterMap(inbox =>
    binding.load(RadifStore.Author.one->at(inbox.owned.owner))
    ->loaded
    ->Option.map(author => {
      inbox: inbox.entity.id,
      name: author.titled.title,
      offered: offers
      ->Array.find(edge => edge.from == inbox.entity.id)
      ->Option.map(edge => edge.level),
    })
  )
}

// An offer standing in the person's Inbox: the node it runs to and the
// title the sealed Invitation carries.
type offer = {to: Radif.id, title: string}

let offers = (binding: RadifTilia.t, standing: standing) =>
  binding.edges(Some(Edge.From(standing.inbox)))
  ->listed
  ->Array.filter(edge => edge.level == Radif.Access.invited)
  ->Array.map(edge => {
    to: edge.to,
    title: edge.payload
    ->Option.flatMap(payload => binding.load(RadifStore.Invitation.one->at(payload))->loaded)
    ->Option.mapOr("a document", invitation => invitation.titled.title),
  })

// ── the editing ─────────────────────────────────────────────────────────

let editing = (
  client: Client.t,
  binding: RadifTilia.t,
  standing: standing,
  document: RadifStore.Document.t,
  first: RadifStore.Section.t,
) => {
  let self = Tilia.tilia({
    client,
    standing,
    document,
    state: TiliaEditor.View.prepare(port(first)),
    others: Tilia.computed(() =>
      standing.founder ? others(binding, standing, ~document=document.entity.id) : []
    ),
    section: first,
    storage: {sections: [], update: _ => (), merge: (~base as _, ~local as _, ~remote) => remote},
    synced: false,
    saved: 0,
    received: 0,
    changed: 0,
    skipped: 0,
    base: port(first),
    pending: None,
    quiet: None,
    cap: None,
    held: 0,
  })
  let flush = () =>
    switch self.pending {
    | None => ()
    | Some(latest) =>
      self.pending = None
      self.quiet->Option.forEach(clearTimeout)
      self.cap->Option.forEach(clearTimeout)
      self.quiet = None
      self.cap = None
      self.base = latest
      save(client, written(self.section, latest))
      ->Promise.thenResolve(() => self.saved = self.saved + 1)
      ->Promise.ignore
    }
  let storage: Section.storage = {
    sections: [port(first)],
    update: sections =>
      sections->Array.forEach(changed =>
        if changed.id == self.section.entity.id {
          self.pending = Some(changed)
          self.quiet->Option.forEach(clearTimeout)
          self.quiet = Some(setTimeout(flush, pause))
          if self.cap == None {
            self.cap = Some(setTimeout(flush, atMost))
          }
        }
      ),
    merge: (~base as _, ~local as _, ~remote) => remote,
  }
  self.storage = storage
  onWindow("blur", flush)
  onWindow("pagehide", flush)
  onDocument("visibilitychange", () =>
    if hidden {
      flush()
    }
  )
  let _ = client.synced(synced => self.synced = synced)
  // The binding folds every answer onto the live record, own write or
  // other device, before any hook hears the delivery. The watch reads the
  // record's blocks and atoms, so it runs on a fold that moved one of them
  // and lands the fold on the view.
  let _ = Tilia.watch(
    () => port(self.section),
    _ => {
      let (changed, held) = arrive(self.state, self.section, ~base=self.base)
      self.changed = self.changed + changed
      self.held = self.held + held
    },
  )
  // The deliveries are counted, and nothing else is done with them here.
  let _ = client.receives(delivery => {
    delivery.entities->Array.forEach(arrival =>
      if Radif.recordId(Radif.unpack(arrival.remote)) == self.section.entity.id {
        self.received = self.received + 1
        if arrival.edit->Option.isSome {
          self.skipped = self.skipped + 1
        }
      }
    )
  })
  self
}

let invite = (opened: opened, other: other) =>
  outcome(reply =>
    opened.client.invite(
      ~inbox=other.inbox,
      ~to=opened.document.entity.id,
      ~level=Radif.Access.edit,
      reply,
    )
  )->Promise.ignore

// ── the screens ─────────────────────────────────────────────────────────

// What the page shows: the join form on a code, the wait on a session that
// holds no section yet, the editor once one stands.
type waiting = {client: Client.t, standing: standing, offers: array<offer>}

type screen =
  | Opening
  | Naming(string)
  | Waiting(waiting)
  | Editing(opened)
  | Failed(string)

type page = {mutable screen: screen, mutable browse: option<Browse.t>}

let page = Tilia.tilia({screen: Opening, browse: None})

let failed = error =>
  page.screen = Failed(
    error->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("unknown"),
  )

// Where the person stands, the documents under their Personal node, and
// the sections attached to the first, as the binding answers them: the
// founder's own document, and the one an accepted offer lands there.
type held = {
  standing: option<result<standing, string>>,
  documents: Radif.loadable<array<RadifStore.Document.t>>,
  sections: Radif.loadable<array<RadifStore.Section.t>>,
}

@val external later: (unit => unit, int) => unit = "setTimeout"

// One browser database a session, as the board keeps it.
let open_ = async (token: string) => {
  let indexed = await outcome(reply => IndexedDbKv.make(~name=`radif:${token}`, reply))
  let client = await Client.make({base: "/_radif", token, kv: indexed.kv})
  let binding = RadifTilia.make(~client, ~clock=SystemClock.make())
  page.browse = Some(Browse.make(~actor=client.actor, ~binding))
  let held = Tilia.carve(({derived}) => {
    standing: derived(_ => standing(binding, ~account=client.actor)),
    documents: derived(self =>
      switch self.standing {
      | Some(Ok(standing)) =>
        binding.load(Radif.under(RadifStore.Document.klass)(standing.personal))
      | _ => NotSet
      }
    ),
    sections: derived(self =>
      switch self.documents {
      | Loaded({data}) =>
        switch data->Array.get(0) {
        | Some(document) => sections(binding, ~document=document.entity.id)
        | None => NotSet
        }
      | _ => NotSet
      }
    ),
  })
  // The screen follows the lists: the first section of the first document
  // opens the editor on it; no document opens the wait, and the founder
  // makes one. The move runs off the tracked read, so what the editor reads
  // is not observed here.
  let making = ref(false)
  let _ = Tilia.observe(() =>
    switch (held.standing, held.documents, held.sections, page.screen) {
    | (_, _, _, Editing(_) | Failed(_)) => ()
    | (Some(Error(message)), _, _, _)
    | (_, NoData({reason: Failed({message})}), _, _)
    | (_, _, NoData({reason: Failed({message})}), _) =>
      later(() => page.screen = Failed(message), 0)
    | (Some(Ok(standing)), Loaded({data: documents}), sections, screen) =>
      switch (documents->Array.get(0), sections, screen) {
      | (Some(document), Loaded({data}), _) =>
        switch data->Array.get(0) {
        | Some(first) =>
          later(
            () => page.screen = Editing(editing(client, binding, standing, document, first)),
            0,
          )
        | None => ()
        }
      | (Some(_), _, _) => ()
      | (None, _, _) if standing.founder =>
        if !making.contents {
          making := true
          later(
            () =>
              opened(client, standing)
              ->Promise.catch(error => {
                failed(error)
                Promise.resolve()
              })
              ->Promise.ignore,
            0,
          )
        }
      | (None, _, Waiting(_)) => ()
      | (None, _, _) =>
        let waiting = Tilia.tilia({
          client,
          standing,
          offers: Tilia.computed(() => offers(binding, standing)),
        })
        later(() => page.screen = Waiting(waiting), 0)
      }
    | _ => ()
    }
  )
}

let accept = (client: Client.t, standing: standing, offer: offer) =>
  outcome(reply =>
    client.accept(~to=offer.to, ~anchor=standing.personal, reply)
  )
  ->Promise.catch(error => {
    failed(error)
    Promise.resolve()
  })
  ->Promise.ignore

// One `POST /member` with the code and the name: the session it answers is
// the person's from here on.
type request = {method: string, headers: dict<string>, body: string}
type response = {ok: bool}
@send external text: response => promise<string> = "text"
@val external fetch: (string, request) => promise<response> = "fetch"

let join = async (code: string, name: string) => {
  let response = await fetch(
    "/_radif/member",
    {
      method: "POST",
      headers: Dict.fromArray([("Content-Type", "application/json")]),
      body: JSON.stringifyAny({"code": code, "author": name})->Option.getOr("{}"),
    },
  )
  let body = await response->text
  if !response.ok {
    JsError.throwWithMessage(body)
  }
  switch JSON.parseOrThrow(body)
  ->JSON.Decode.object
  ->Option.flatMap(fields => fields->Dict.get("session")->Option.flatMap(JSON.Decode.string)) {
  | Some(token) =>
    replaceState(Nullable.null, "", `?radif-session=${token}`)
    await open_(token)
  | None => JsError.throwWithMessage("the member answer names no session")
  }
}

module Status = {
  @react.component
  let make = (~opened: opened) => {
    TiliaReact.useTilia()
    <p className="status">
      {React.string(
        (opened.synced ? "in step" : "out of step") ++
        ` · saved ${opened.saved->Int.toString}` ++
        ` · received ${opened.received->Int.toString}` ++
        ` · changed ${opened.changed->Int.toString}` ++
        ` · held ${opened.held->Int.toString}` ++
        ` · skipped ${opened.skipped->Int.toString}` ++ (
          opened.pending == None ? "" : " · unsaved"
        ),
      )}
    </p>
  }
}

// The founder's side of the share: one line a member, one button to offer
// the section at `edit`, and the level the offer stands at once made.
module Others = {
  @react.component
  let make = (~opened: opened) => {
    TiliaReact.useTilia()
    <ul className="others">
      {opened.others
      ->Array.map(other =>
        <li key=other.inbox>
          {React.string(other.name)}
          {switch other.offered {
          | None =>
            <button onClick={_ => invite(opened, other)}> {React.string("invite to edit")} </button>
          | Some(level) if level == Radif.Access.invited => React.string(" · invited")
          | Some(level) => React.string(` · ${Radif.Access.name(level)}s`)
          }}
        </li>
      )
      ->React.array}
    </ul>
  }
}

module Editor = {
  @react.component
  let make = (~opened: opened) =>
    <main>
      <h1> {React.string(opened.document.titled.title)} </h1>
      <TiliaEditor.View
        state=opened.state section={port(opened.section)} storage=opened.storage types
      />
      <Status opened />
      {opened.standing.founder ? <Others opened /> : React.null}
    </main>
}

// A member's wait: the offers standing in their Inbox, each with one button.
module Wait = {
  @react.component
  let make = (~waiting: waiting) => {
    TiliaReact.useTilia()
    let {client, standing, offers} = waiting
    <main>
      <p className="status">
        {React.string(offers->Array.length == 0 ? "waiting for an invitation" : "invited")}
      </p>
      <ul className="others">
        {offers
        ->Array.map(offer =>
          <li key=offer.to>
            {React.string(offer.title)}
            <button onClick={_ => accept(client, standing, offer)}>
              {React.string("accept")}
            </button>
          </li>
        )
        ->React.array}
      </ul>
    </main>
  }
}

// The join form: a name, and the code the address carries.
module Join = {
  @react.component
  let make = (~code) => {
    let (name, setName) = React.useState(() => "")
    let joining = event => {
      ReactEvent.Form.preventDefault(event)
      if name->String.trim != "" {
        page.screen = Opening
        join(code, name->String.trim)
        ->Promise.catch(error => {
          failed(error)
          Promise.resolve()
        })
        ->Promise.ignore
      }
    }
    <main>
      <form className="join" onSubmit=joining>
        <label>
          {React.string("your name")}
          <input
            value=name
            autoFocus=true
            onChange={event => setName(_ => ReactEvent.Form.target(event)["value"])}
          />
        </label>
        <button type_="submit"> {React.string("join")} </button>
      </form>
    </main>
  }
}

module Croquis = {
  @react.component
  let make = () => {
    TiliaReact.useTilia()
    <>
      {switch page.screen {
      | Opening =>
        <main>
          <p className="status"> {React.string("opening")} </p>
        </main>
      | Naming(code) => <Join code />
      | Waiting(waiting) => <Wait waiting />
      | Editing(opened) => <Editor opened />
      | Failed(message) =>
        <main>
          <p className="status"> {React.string("the page could not open: " ++ message)} </p>
        </main>
      }}
      {switch page.browse {
      | Some(browse) => <Browse.View browse />
      | None => React.null
      }}
    </>
  }
}

let style = `
  :root { color-scheme: light; --black: #000; --grey: #6b6b6b; --faint: #f1f1f1; --red: #e2231a; }
  body { margin: 0; font-family: Jost, Helvetica, Arial, sans-serif; font-size: 1.15rem; line-height: 1.5; color: var(--black); background: #fff; }
  main { max-width: 46rem; padding: 3rem 2rem; }
  h1 { font-size: 3rem; font-weight: 700; letter-spacing: -0.04em; margin: 0 0 2rem; }
  h1::after { content: ""; display: block; width: 5rem; height: 0.5rem; margin-top: 1rem; background: var(--red); }
  .editor { outline: none; caret-color: var(--red); border-top: 2px solid var(--black); padding-top: 1rem; }
  .editor p, .editor li { margin: 0 0 1rem; min-height: 1.5em; }
  .editor code { font-family: "IBM Plex Mono", monospace; font-size: 0.85em; background: var(--faint); padding: 0.05em 0.3em; }
  .atom { display: inline-block; cursor: pointer; border-radius: 2px; }
  .display { text-align: center; }
  .status { color: var(--grey); font-size: 0.85rem; border-top: 1px solid var(--faint); padding-top: 0.5rem; }
  .others { list-style: none; padding: 0; margin: 0.5rem 0; color: var(--grey); font-size: 0.85rem; }
  .others li { display: flex; align-items: center; gap: 0.75rem; margin: 0.25rem 0; }
  .join { display: flex; align-items: flex-end; gap: 0.75rem; }
  .join label { display: flex; flex-direction: column; gap: 0.25rem; color: var(--grey); font-size: 0.85rem; }
  input { font: inherit; font-size: 1.15rem; padding: 0.25rem 0.5rem; border: 1px solid var(--grey); border-radius: 2px; }
  button { font: inherit; font-size: 0.85rem; padding: 0.2rem 0.7rem; border: 1px solid var(--black); border-radius: 2px; background: #fff; color: var(--black); cursor: pointer; }
  button:hover { background: var(--black); color: #fff; }
`

ReactDOM.querySelector("#root")->Option.forEach(root =>
  ReactDOM.Client.createRoot(root)->ReactDOM.Client.Root.render(
    <>
      <style> {React.string(style ++ Browse.style)} </style>
      <Croquis />
    </>,
  )
)

switch (session, code) {
| (Some(token), _) =>
  open_(token)
  ->Promise.catch(error => {
    failed(error)
    Promise.resolve()
  })
  ->Promise.ignore
| (None, Some(code)) => page.screen = Naming(code)
| (None, None) => page.screen = Failed("the address names no session and no code")
}
