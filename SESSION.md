# Session

Step 1 of the session fills **Intention**, step 3 fills **Technical**. When
the session closes, any choice worth remembering is appended to
`DECISIONS.md` and this file is cleared back to exactly what you are
reading. See `CONTRIBUTING.md`.

## Intention

Started 2026-09-26. This session brings a lapa section into the editor as a
live row. A reader can keep typing while another device edits the same
section. An arrival changes only the block that moved.

The work serves the reader of a course and the host that embeds the editor.
The reader should see both authors' words without losing the caret. The host
should receive one whole section when the editor saves.

### The seam

In `@lapa/tilia`, a record is one live tilia object. `Lapa.assign` folds an
arrival onto that object. It splices a many-field onto the array that already
stands. The array keeps its identity. An entry whose id remains also keeps its
identity. The array takes the arrived order.

A section's `blocks` and `atoms` are two such arrays. The editor must use
those arrays and their entries directly. Each block view reads one entry. A
change to one entry then re-renders one block.

### The editor state

The editor keeps two named values:

- `row` is the last section that landed or was saved.
- `typed` is keyed by block id and atom id. It holds an edit made since the
  last save.

The section on screen is the row with `typed` applied. A merge may keep a
typed block that the remote row removed. The screen keeps the place that the
merge returned for that block. How the core represents that order belongs in
**Technical** after the fixture is agreed.

The word is `typed`, not `draft`. In lapa, a draft is a stored row with the
Draft facet. It syncs, can be proposed and can settle.

An act that leaves the block list unchanged records its changed blocks and
atoms in `typed`. It does not call the port. The host decides when to save. A
save sends the displayed section to the port, clears `typed` and makes the
saved section the row.

An act that changes the block list saves at once. A join removes an id. A
split creates an id. A move changes the order. A block removal removes an id.
The `typed` dictionary cannot represent those structural changes.

An editor save and a lapa push are separate. The host schedules the editor
save. Lapa may batch the later network push. A push throttle belongs to sylva
and does not change this port contract.

### A row landing

The core does not implement a merge algorithm. The port supplies one merge
function. When a row lands, the core calls it once with three sections:

- `base` is the current row before the arrival.
- `local` is the displayed section.
- `remote` is the row that just landed.

The returned section becomes the screen. The remote row becomes the new
`row`. Any block or atom in the result that still differs from the new row
remains in `typed`. The screen keeps the order returned by the merge. The
Operations page owns the caret map when the result changes the focused block.

The core fixture uses a small merge stub. It keeps a local block or atom when
it differs from the base. Otherwise, it takes the remote block or atom. The
stub proves the port crossing. It does not try to copy lapa's merge.

`@lapa/editor` supplies `Lapa.Merge.three`. It merges entries by id and their
text word by word. Its fixtures own the conflict cases and git markers.

### The two merge moments

An online arrival can meet text that the store has never seen. The editor
passes the current row, the displayed section and the arrived row to the
port's merge function.

An offline conflict happens after a section was saved. Lapa merges the outbox
row with the pulled row against the kv row. That result later lands in the
editor as a remote row. If the reader has typed newer text by then, the normal
arrival rule runs over it.

The two merges happen at different boundaries. The editor merges an arrival
with unsaved text. Lapa merges two saved rows during a pull.

### Package boundaries and order

1. `@epure/editor` owns `row`, `typed` and arrival behavior. It calls the
   port's merge function on arrival. It saves edits that change the block
   list at once.
2. `@tilia/editor` reads the live arrays through one leaf per block. It keeps
   unchanged entry objects and DOM nodes. It maps the caret when one focused
   block changes.
3. `@lapa/editor` defines the Section and Document classes. It fills the port
   from the live record and supplies `Lapa.Merge.three`.

Each package gets its own fixture before its implementation changes. Each
fixture stops for agreement.

### Fixture stage

Stage 2 is current. `packages/editor/src/design/storage/Typed.feature` is the
proposed core fixture. It is not agreed. No steps are written.

The fixture now settles these edges:

- save timing follows the resulting block list, not the name of the act;
- text input, an atom edit, a mark, a link and a paste within one block stay
  typed and do not reach the port;
- a join, split, move, block removal or paste of several blocks saves at once;
- an immediate structural save sends and clears typed changes in other blocks;
- the current row is the next arrival's base, whether it landed or was saved;
- a typed block that the remote row removed keeps the place returned by the
  merge.

The fixture describes the last rule as behavior. It does not prescribe a
separate list of ids or another representation for the screen order.

`Draft.feature` is gone from the worktree. Do not restore or bind the
rejected draft design.

The two other fixtures are proposed as titles. Each is written in full and
agreed before its steps.

**`@tilia/editor`, the browser suite, `packages/tilia/src/design/`.** What
the core cannot see: which block re-rendered, which object and DOM node
survived, and the caret after a native edit.

- each block is a leaf over its own entry, so a change to one entry
  re-renders one block
- an act keeps the object of every id that stays, and the section's arrays
  keep theirs
- typing re-renders the typed block alone
- a landed row re-renders only the block it changed
- a landed row on another block does not rebuild the block that holds the
  caret
- a saved block keeps its object when a row lands on another block
- a block the merge changes under the caret is rebuilt and the caret follows
  the map; the map itself is the core's, on the Operations page
- a fold on the live record lands as a row on the editor, since the core
  observes nothing
- `save` is a call on the editor that the host makes

**`@lapa/editor`, move 3, `packages/lapa/src/design/`.** Over `MemoryKv` and
a quiet wire, with a second device's row queued for the next pull, as
sylva's `Parc.res` does. It owns the store and the real merge.

- a stored section reads into the port as the record's own arrays
- a save writes one row through the store
- a split writes a new entry under the editor's id
- a second device's row folds onto the live record and reaches the editor
  as a landing
- other words of one block both land
- the same words take markers and name the block in conflict
- a block typed here and dropped there comes back in conflict
- an atom's source merges word by word like a block
- the same words of an atom's source take markers
- a merged pull reaches the editor as one landed row

Not in `@lapa/editor`: the save cadence, which the host schedules; the pull
merge of two saved rows, which is sylva's; and the conflict notice, which is
out of scope. One ask on sylva: `Merge.three` runs in place on records, and
`@lapa/editor` holds three plain sections, so sylva should expose the
entry-list merge on plain data, with a scenario in its `Merge.feature`.

### Croquis and working tree

The croquis under `packages/lapa/src/croquis/` proved the path with two real
browsers. A founder can make a section. A second member can join by code,
accept an edit offer and receive the section. The page now reads the section
through `@lapa/tilia` and keeps the live record that the binding returns.

The run proved these points:

- a fold can change one block without rebuilding another block;
- an own write comes back as a stamped delivery;
- rebuilding the focused block without a caret map scrambles later input;
- a host pause can collect many keystrokes into one editor save;
- a live plan can reach sections under a Personal node.

The package links `lapa`, `@lapa/db`, `@lapa/server` and `@lapa/tilia` to
`../sylva`. It also links the tilia builds that sylva uses. Vite deduplicates
tilia, query, React and React DOM so the page uses one reactive runtime. These
links remain until matching packages are published.

Nothing in this session is committed. The working tree also holds the
croquis, its vite wiring, the package links and the lockfile changes. Preserve
them while the fixture settles.

### External findings

The croquis exposed three sylva issues:

- The generator used `Lapa.direct` for a `many text` field. Such a field needs
  `Lapa.many`.
- `lapa dev` could exit on `EPIPE` after a browser disconnected.
- Client boot read an asynchronous kv value as if it arrived at once. A
  `LaterKv` scenario and fix exist uncommitted in sylva.

These findings belong to sylva sessions. They do not change the editor
fixture.

### Out of scope

Sections ordered under a document, proposals, stored drafts and the conflict
notice remain later work. The lapa push throttle and root icons also belong
to sylva.

## Technical

Proposed 2026-09-27, for the core fixture alone. `@tilia/editor` and
`@lapa/editor` get their own approach when their fixtures are written.

### The state

One new module in the core, `feature/Typed.res`. Its state is two values:

- `row`, a `Section.t`: the current row, landed or saved.
- `doc`, a `Doc.t`: the displayed document, with its selection and its box.

`typed` is a read, not a stored value: the blocks and atoms of
`Storage.write(doc)` whose text differs from `row`, in the document's order.
This is how SESSION.md's two named values land: `row` is held, `typed` is
computed. The order a merge returns is the order of `doc`, so a typed block
the row dropped keeps its place with no list of ids beside it.

### The four moves

- `act(state, edit)` applies the pure edit to `doc`. When the ids in order
  are the same before and after, the state holds the new `doc` and the port
  hears nothing. When they differ, `act` saves. That is the fixture's rule
  that save timing follows the resulting block list.
- `save(state, storage)` writes `doc` as a section, hands it to
  `storage.update`, and makes it `row`. Nothing else changes, so `typed`
  reads as empty afterwards.
- `land(state, storage, remote)` calls `storage.merge` once with `row` as
  base, `Storage.write(doc)` as local and `remote`, reads the answer into
  the new `doc`, and makes `remote` the row. The selection carries over: the
  caret stays on its block, and when that block's text changed, its offset
  maps through the common prefix and suffix of the old and new text, as
  `Edit.input` already maps a native edit with `commonPrefix` and
  `commonSuffix`. A block the answer no longer holds drops the selection.
  The box carries over the same way on its atom's source. The fuller map, a
  diff of the old text against the new, is move 2 on the Operations page.
- `typed(state)` is the read above.

### The port

`Section.storage` gains one field, `merge: (~base, ~local, ~remote) => t`.
The core never supplies one. The steps supply the fixture's rule: a local
block or atom where it differs from the base, the remote one otherwise. The
in-memory host of the dev page and the demo supply one that answers the
remote, since nothing lands there. The croquis supplies the same until
`@lapa/editor` hands it `Lapa.Merge.three`.

`Storage.commit` stays: it is the write crossing, and `View.apply` and the
Storage cards run on it until `@tilia/editor` moves onto `Typed.act` and
`Typed.save` in its own session. That session removes the call from the
view; this one changes no view.

### The steps

`TypedSteps.res` beside the fixture. The given "a section" builds the state
from the table: each row becomes a notation line, `@id text`, with `║` read
as `|`, and `Notation.read` gives the document with its caret or selection
and its marks. "its atoms" adds the atoms through `Storage.readAtoms`, with
the type and source joined by a newline as the port holds them. The steps
record every `update` and every `merge` call on the storage they build.
"the section shows" writes `doc` back with the caret as `║`, "the typed
text is" reads `typed`, "the row is" reads `row`, and "the port receives"
reads the last update. The acts reuse the Operations harness: `Steps.act`
turns "types", "presses backspace", "presses enter", "presses bold", "links
the selection to", "pastes", "clicks", "moves the block up" and "edits atom"
into the same act lines the cards use, so one harness drives both fixtures.
The split's new id is minted as the harness mints, the first free letter.

### Rejected

- `typed` as a stored dictionary keyed by id, with a list of ids for the
  order. The displayed document already holds every typed text and the
  order, and a dictionary beside it is a second copy to keep level. The cost
  of the read is writing the document and comparing a few dozen strings
  against the row on each call.
- A merge in the core, word by word. Refused in Sol's review: the core would
  carry diff3 and a second base. The cost of the port's `merge` is one
  function every host must supply, even a host that never lands a row.
- A merge at save time with the base on the port. Refused in "The two
  merges": it hides the other author's words for the whole pause and changes
  `update`'s shape.
- Every act written through the port, the host merging. Refused in the night
  handoff: a keystroke is not a save.
- The selection dropped on landing and placed again by the view. The
  fixture shows the caret after a landing, so the map is the core's.

### Built (2026-09-27, night)

Stages 4 and 5 are done: `Typed.res`, `TypedSteps.res`, `merge` on the
port, and a merge answering the remote in the three hosts that never land a
row, the Storage steps, the demo page and the croquis. The core suite passes,
175 tests, and the browser suite, 118 cards and 8 skipped. Nothing is
committed. What the binding found:

- `@epure/vitest` passes no doc string, and every digit in a step's text
  reads as a `{number}`, so `a8f1` cannot stand bare in a step. The paste
  scenario became `pastes "…"` with `\n` inside the string, and the atom
  edits quote the id: `edits atom "a8f1" to read "…"`. Two changes to the
  agreed fixture, both in the wording of a step and not in a rule.
- The backslash in `X \ A` did not bite: it only appears in landed and
  expected tables, which the steps read as the port's own text, and never
  in a given table, which goes through the notation.
- The harness's `click` keeps the focused block and takes the offset, so
  the steps place a click by finding the block whose plain text is the
  clicked text. The harness is unchanged.
- The stub merge appends what only the remote holds after the local order.
  No scenario has a remote-only block, so the rule is the steps' alone.

### Simulated collaborator (2026-09-28)

The dev page and the site's demo gain a toggle that simulates a
collaborator, so the typed text can be tried by hand. Every five seconds it
takes the row it last sent, changes it with a line by a woman poet, and
lands the result through `Typed.land`. Odd changes add a block, insert a
phrase into a block or join two plain blocks. Even changes aim at the block
that holds the caret: they type two or three words at the caret, split the
block there, or join it to a neighbour. Only a block whose content changed
is bumped. The view's write on every act is not a save here: the host
saves after each landing, and the collaborator's next change starts from
that save, so the typed text is what came since the last tick. Without the
save, the typed span of an edited block grew over every edit since the
start and swallowed every remote change to it.

The demo host's `merge` keeps the remote order. A block or atom both sides
changed merges its text: each side's change is its span between the common
prefix and suffix with the base, two spans that do not overlap both land,
and the reader's text stands otherwise. A block the reader removed and the
remote left alone stays removed. A typed block the remote dropped
keeps its place after the block it followed on screen. This is a stand-in
for `Lapa.Merge.three` until sylva exposes it on plain data. The croquis
still answers the remote. Dev sources only: `Collaborator.res`, `Poets.res`,
`Course.res`, `Page.res`, `Demo.res` and the demo page's mount point.

Leaving the atom box put the browser's caret at the root's start and
scrolled the page there. `focusRoot` now places the DOM caret on the
model's first and focuses with `preventScroll`.

### Handoff (2026-09-27, night)

The core session is built and green, and waits for Anna's review. The
working tree holds everything, see `git status`: the fixture, the steps,
`Typed.res`, `merge` on the port, the three hosts, and the croquis, links
and lockfile from the earlier moves. Nothing is committed.

**To review.** `Typed.feature` against the two step rewordings under
**Built**; `Typed.res`, sixty lines; `TypedSteps.res`, in particular the
stub merge and the click. `Storage.commit` still stands and `View.apply`
still writes on every act, by design: the view moves in the tilia session.

**Decisions to append to `DECISIONS.md` when the session closes**, in its
form. They are proposed, not written.

**2026-09-27 — An arrival merges through the port, at arrival**

A row that lands meets text the store has never seen: the keys typed since
the last save. The core hands the host's `merge` three sections, the row it
last took, that row with the typed text over it, and the row that landed,
and displays the answer. Lapa's own merge runs at the pull, over two saved
rows, and the two never meet the same edit: offline nothing lands, online
the outbox is empty.

Refused: a merge coded in the core. It would carry diff3 and run against
another base than lapa's. Refused: a merge at save time with the base on
the port. It hides the other author's words for the whole pause and changes
`update`'s shape.

Costs every host one `merge`, even a host that never lands a row, which
answers the remote.

**2026-09-27 — Typed text is a read, not a value**

The editor holds the current row and the displayed document. The typed
text is what the document holds that the row does not, in the document's
order. A save writes the document and makes it the row; a landed row
becomes the row and the merge's answer becomes the document.

Refused: a dictionary of typed text keyed by id, with a list of ids for the
order. The document already holds both, and the dictionary was a second
copy to keep level.

Costs a write of the document and a comparison against the row on every
read of the typed text.

**2026-09-27 — Save timing follows the resulting block list**

An act whose result keeps the same ids in the same order is typing, and
the host decides when to save it. Any other result saves at once: a join,
a split, a move, a removal, a paste of several lines. The word is `typed`;
a draft is lapa's, a stored row with the Draft facet.

Refused: a save on every act. A keystroke is not a save, and `@tilia/query`
and lapa both model an explicit write. Refused: naming the acts that save.
A paste saves or not by its shape.

Costs the host one call, `save`, and the tilia binding a way to expose it.

**Open, not decided.** The caret on a landed block maps through the common
prefix and suffix of the old and new text, as `Edit.input` maps a native
edit. The fuller map, a diff, is move 2 on the Operations page. And the
merge stub's rule for a block only the remote holds is the steps' alone.

**Then.** Bring "Where it stands" on the design page level with the code:
the port has a merge, the core holds the row and the typed text, saves are
the host's for text and immediate for the list. Clear `SESSION.md` and
open the tilia session on the titles under **Fixture stage**: the two
layers as one leaf per block, `save` on the mounted editor, `View.apply`
onto `Typed.act`, and the landing through `Typed.land` from the binding's
watch.
