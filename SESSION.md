# Session

Step 1 of the session fills **Intention**, step 3 fills **Technical**. When
the session closes, any choice worth remembering is appended to
`DECISIONS.md` and this file is cleared back to exactly what you are
reading. See `CONTRIBUTING.md`.

## Intention

Started 2026-09-26. Sylva now holds what the editor asked of lapa first: a
many-field is an ordered list of entries, each an id and a text, a list
merges entry by entry, and an entry's text merges word by word with git
markers on a conflict. Sylva's `docs/NEXT.md` names `@lapa/editor` as the
next stage and leaves positions on `parents`, per-entry tombstones in a
draft and a conflict notice for later. This session builds toward
`@lapa/editor` here, beside `@tilia/editor`, so that the shape can move
before it migrates into sylva.

**The seam.** In `@lapa/tilia` a record is one live tilia object, and an
arrival is folded onto it with `Lapa.assign`. A list is spliced onto the
array the record already holds: the array keeps its object, an entry whose
id stays keeps its object, and the array takes the arrived order. So the
reader of one entry's text is the only one notified when that entry
changes. A section's `blocks` and `atoms` are two such arrays, and the
editor's blocks and atoms must be those very objects. In tilia a write of
the same value is a no-op, so the rule is about identity alone: never a new
object for an id that stands, never a new array for the section.

**What stands against it.** `@tilia/editor` keeps one immutable `Doc.t`
and replaces it whole on every act. The root component reads it, so every
act re-renders every block, and a `revisions` counter forces React to
rebuild the blocks whose content changed. `View.load` bumps every block.
The design page already says one tracked entry per block, keyed by id, and
only the block whose entry changed re-renders.

This session has two steps before its three parts, and the parts follow
in this order. Each stops for agreement.

**0. The second field is `atoms`.** The design page split the stored thing,
an entry, from the piece drawn from it, an atom. Lapa owns the word entry
for every element of a many-field, so from the binding on every sentence
would have had to say which entry it meant. A block already uses one word
for the stored line and the drawn paragraph, and an atom now does the same.
The rename runs through the model, the port, the notation keys `atoms` and
`atomsAfter`, the fixtures, the view, the site and the design page. Agreed
2026-09-26; done in the working tree.

**0b. A croquis of two people editing one section.** Before any scenario
for the parts below, a sketch under `packages/lapa/src/croquis/`, a dev
source, shows the whole path in real browsers: Ben edits and saves, the
change syncs through `lapa dev`, and Aisha sees it land and continues her
own edit. It uses what stands today and nothing more. `lapa dev .data`
runs from sylva's server package beside vite, and vite carries the wire
under `/_lapa/` as the board does. Ben is the founder: his browser opens
on the session the first line prints. Aisha joins with the admission code
on that line, one `POST /member` with the code and her name, and opens on
the session it answers. Sign-in is not needed: sessions exist, sign-in does
not, and both are as lapa means them today. A member reads the Domain and
reading is not editing, so Ben invites Aisha's inbox to the section at
`edit` and Aisha accepts onto her Personal node, with the client's
`invite` and `accept`, one button on each side. The session stays in the
address and never in local storage, so two tabs are two people.

The page opens the client on its session, defines the Section class once
through the desk's `define` tool on `/mcp`, finds or makes one section
under Ben's Personal node, and mounts today's `@tilia/editor` over it:
every act packs the record and writes it with `upsert`, and every delivery
the client hands out reloads the view. The first version is naive on
purpose: it uses `View.load`, so it shows the whole section rebuilt and the
caret lost with a real server between two people. Then the sketch moves
the view onto the live arrays, and the difference is seen before a scenario
is written.

It teaches what the parts below need: how a delivery reaches the page and
how fast, what lapa's merge does to the block Aisha is typing in when Ben's
edit to the same block lands, whether the spliced entry object is what a
block leaf reads, and what the share ceremony costs a person.

Three moves, each stopping for agreement: the package with its links and
one browser saving to the server; the second browser joining by code and
invited to edit; the two editing together. The sketch goes when the
scenarios replace it, in a commit like any other, and a keep file holds the
folder. Agreed 2026-09-26. The first move is done in the working tree. The
second is done in the working tree on 2026-09-27: the page joins on
`lapa-code` with a name, puts the session it is answered in the address,
and waits; the founder's page lists the Domain's other members and offers
the section at `edit` with one button; the member's page shows the offer
and accepts it with one button, and the section lands. Driven from node
over the live server: the offer carries the title, the acceptance lands the
six blocks. One thing learnt: an accepted offer moves onto the member's
Personal node, which the founder does not reach, so the founder's store
cannot tell an acceptance from no offer, and the list shows "invited" only
while the offer stands in it.

**1. `@tilia/editor` onto the seam.** The state holds the section's two
live arrays. Each block is a `leaf` that reads its own entry's text and
parses it into runs when it renders, so a change to one entry re-renders
one block, whether a key or another device changed it. An act reads the
document off the live arrays, runs the pure edit, and writes the result
back by the splice rule: an id that stays keeps its object, and the array
takes the new order. The port's `sections` becomes the live section itself,
and `update` fires when a splice changed something. The block the browser
touched is still rebuilt, since that rule is about React reconciling
against a native edit. The demo's in-memory host splices the same way. The
82 cards keep running in Chrome, and one rule is added: an arrival in
another block does not rebuild the focused block.

**2. `@epure/editor`, the arrival on the focused block.** A remote text
lands in the block that holds the caret. The caret moves through a diff of
the old text against the new, so the typist never sees it jump. One pure
function on one block, and one small group of cards on the Operations page.

**3. `packages/lapa`, package `@lapa/editor`.** A `Section` class with
`blocks` and `atoms` as `many text`, and a `Document` class beside it.
`make` over a client binds a section record to the port: `sections` is the
record's own arrays, and `update` packs the record and writes it through
the store. Arrival costs nothing here, because `Lapa.assign` already
splices onto the arrays the blocks read. The scenarios run over a
`MemoryKv` client and a quiet wire, as sylva's `Parc.res` does, with a
second device's row queued for the next pull: a stored section reads into
the port, an act writes one row, a split writes a new entry under the
editor's id, an edit from another device to another block arrives and
re-renders only that block, two edits to one block merge word by word, and
a conflict arrives as markers in one block.

Who it serves: the reader of a course who edits a section while another
device or an author edits it too, and sees only the block that changed
move.

Tooling: the local registry holds lapa at beta.16, from before the list
kind. `packages/lapa` links to `../sylva/packages/*` with pnpm's `link:`
protocol until beta.18 is published. Agreed 2026-09-26.

Out of scope until lapa builds it: sections in order under a document,
drafts and proposals of a section, and the conflict notice in the view.

## Where it stands (2026-09-26, evening)

Step 0 is done in the working tree. Step 0b, move 1, is done: `packages/lapa`
links to `../sylva/packages/*`, `pnpm dev` there runs `lapa dev .data` and
vite, and Ben's browser opens on the founder's session, finds or makes one
section under his Personal node, saves every act through `upsert`, and reads
it back after a reload. A second device on the same session receives the
change. Driven headless in Chrome; nothing is committed.

What move 1 found, in the order it was met:

- **The generator writes `Lapa.direct` on a `many text` field.** `Lapa.entries`
  answers `Lapa.many`, so the generated `Course.res` did not compile. No
  scenario in sylva generates a many field of a scalar kind. The fix is one
  line in `Typing.res`, `fieldHandles`: the phantom is `Lapa.many` when the
  field's kind is `Entries`. The sketch patches the file by hand and asks
  for `--types` only on a fresh deployment.
- **`lapa dev` dies on `EPIPE`.** When a browser goes away, the next write to
  its socket raises an unhandled error and the process exits. `Sockets.res`
  sends without an error handler. Seen twice, through vite's proxy.
- **The client's boot assumes the kv answers at once.** After the first
  pull, `Client.make` composes the `context` by calling `store.get` on the
  Account and switching on the answer in the next statement (`Client.res`,
  the `context` block near line 835). `MemoryKv` answers before the call
  returns, so the author is there. `IndexedDbKv` answers on a later task,
  so the author is still `None`, and the boot throws `missingField` on the
  Account: "does not have a required field". The board fails the same way,
  which Anna's console confirmed. The fix is to await the read, with the
  `find` helper the boot already uses two hundred lines above, and the
  scenario is a client booting over a kv that answers on the next tick. No
  scenario in sylva ran the client over a kv that answers later. Fixed in
  sylva the same evening, with `LaterKv` beside `MemoryKv` and the suite
  run over both; uncommitted there. The sketch is back on `IndexedDbKv`,
  and the board opens on the same deployment.
- **A naive reload while typing scrambles the block.** The client's own
  writes come back as deliveries, and `View.load` on each one rebuilt the
  block under the caret: letters landed at old offsets and a word was cut.
  This is the case the seam work exists for, now seen with a real server.
- **Every keystroke is a save.** One sentence was 26 upserts, and the client
  batched them into two pushes. Debouncing is the host's choice, as the
  design page says.

The naive reload is gone. A delivery naming the section is folded onto
the live record with `Lapa.assign`, and `arrive` in the sketch lands it on
the view block by block: a block whose text, form and atoms did not move
keeps its object and its DOM node, a block that did is rebuilt alone, and
a caret in a rebuilt block is mapped through the common prefix and suffix
of the old and new text. A delivery whose row this device still holds in
its outbox is skipped, since the row coming back is older than the outbox
and the next echo carries what stands. Measured with two devices on one
session, headless:

- Ben types in block 1: his own echo comes back as 2 deliveries, changes 0
  blocks, and 1 is skipped while his outbox still holds the row.
- The device, caret parked in block 2: block 1 changes, block 2 keeps the
  DOM node it had, and the caret stays at its offset.
- Ben types at the start of block 2: the device rebuilds block 2 alone,
  and its caret follows the rule for a change before it.

Two things the run showed in passing. An own write returns as a delivery
because the server stamps the row, and until then the local row is
provisional; that is the normal course, not noise. And `End` in a wrapped
block goes to the end of the visual line, not the block, so a probe that
wants the block's end has to say so.

Saves are debounced in the sketch, with a cap: the port's `update` keeps
the latest section, every act restarts a two second pause, the first
unsaved change starts a ten second cap that nothing restarts, and
whichever fires first writes and clears both. Blur, the tab going hidden
and `pagehide` write at once. Measured: a sentence and a stop save at
2.1 s; a burst of a letter every half second saves at 10.2 s and again
2 s after it ends; a blur saves at once. The row's version on the server counts pushes, so with the
throttle saves, pushes and versions are about one number.

The block id is four characters of base36, minted by `@tilia/editor`
against the document and against what the mint handed out and the
document has not taken yet, since a paste asks for several at once. The
demo and the harness keep their own mints, letters and `e1`. The browser
suite passes, 118 cards and 8 skipped.

The throttle opened the merge question, which had been hidden by a save
per keystroke. A delivery that changes a block the person has changed
since the last write is older than what they typed, so `arrive` holds the
local text for that block, and the next write carries it over the other
person's change: last writer wins on that block. Measured: the device
typed in block 2 and did not save, Ben changed block 2 and blurred, the
device held it and kept its own words. The three sides are all in hand,
the base as last written, the local document and the arriving row, and
`Lapa.Merge.entries` merges two lists of entries against a base with diff3
over the words of an entry both sides changed. So the merge is the
binding's to do, whether saves are throttled or not: lapa's client hands a
holder the three rows and folds nothing itself. That is move 3.

Move 2 is next: Aisha joins with the code and is invited to edit. Then
`arrive` moves out of the sketch: the caret map into `@epure/editor` as
cards, and the block by block landing into `@tilia/editor`.

## Move 3, reshaped (2026-09-27)

The device that only reads stopped updating after the first delivery: "in
step · saved 0 · received 18 · changed 1 · held 17". `arrive` holds a block
whose local line differs from `base`, and `base` moves only when this device
writes. A remote change accepted into the view differs from `base` at once,
so every later delivery to that block was held. The rule is the sketch's,
not lapa's: the client already keeps the unsaved state in its front, marks
an arrival that collides with a staged write in `edit`, and hands the row
the kv held before the pull in `local`. The two second pause put the typed
text in `self.pending`, where the client cannot see it, and the sketch had
to rebuild the outbox by hand.

**Agreed.** Every act writes through the client, and the throttle moves to
the push. `pending`, `base`, `held`, the two timers and the blur and
`pagehide` handlers leave the sketch. A block with local typing is a block
the client marks in `edit`, and that check is the only held rule; it is the
`skipped` counter today. `arrive` stays for the block by block landing and
the caret map, which are the parts the plan moves into `@epure/editor`.

**Through `@lapa/tilia`.** The sketch reads the section as a loadable
through the binding, in place of `ofClass` and `stored`, so the binding is
tested on a record two people edit, which no scenario in sylva does. The
binding was built to take the work of keeping a view level with the
database off the app. Where the sketch still has to do that work, the
binding changes, in sylva, with a scenario in `LapaTilia.feature`. Three
things the move has to find out, in this order:

- **What plan reaches the one section.** The sketch asks the store's index
  once, with `client.store.seek` on the Entity `class` field, which answers
  ids and ends: no plan, no anchor, and nothing live. The plan for it is the
  place head, `Lapa.under(Section.klass)(personal)`: what hangs under the
  person's Personal node, walked by edges. The founder makes the section
  under Personal, and an accepted offer moves it onto the member's Personal
  node, so one plan serves both. Whether the place head follows an offer
  that lands after the plan is open is the first thing to see.
- **What the binding folds while a write is staged.** The store's `merge`
  runs `Lapa.assign` on every clean record. If the plan channel answers the
  front's row, the fold is a no-op and the live record keeps the typed text.
  If it answers the pulled row, the live record steps back until the push
  lands, and the binding has to honour the outbox. A scenario pins whichever
  it is.
- **How `arrive` hears a fold.** Today the sketch folds the row itself in
  `client.receives` and lands it on the view in the same call. With the
  binding folding, the sketch needs to hear that the live record moved, from
  the binding or from the same hook after it.

**The push throttle, in sylva.** A write lands in the front at once and the
push waits: a pause restarted by every write, and a cap started by the first
write that nothing restarts, both in the client's config with defaults of
zero, so every scenario that stands keeps its timing. Blur, the tab hidden
and `pagehide` push at once, in the client, since it owns the front. The
scenarios go in `Sync.feature` beside "An edit while the push flies lands
after it". The version count on the server stays about one per pause, as
measured.

Who it serves: the same reader, and the app developer `@lapa/tilia` was
built for, who should not have to write `arrive`'s held rule to show a
section two people edit.

**Home is the Account.** Nothing links to an Account, so every node the
client holds hangs under it, and sync already descends from it: the
client's kv is the trace of everything linked to the Account. The pull
carries the Account row, which is how the client learns `actor`, so naming
it `home` exposes nothing new to the person's own client. The place head
walks one hop, and an accepted share anchors in a Personal node, so the
plan is a class head anchored on the Account: on the client that reach is
the whole kv, and the evaluator answers it with the class seek. To see the
graph as the client holds it, the sketch has a small browser under the
page, `Browse.res`: the path from the Account down its edges as crumbs,
one row an edge with an icon, the title, a short tag of the id and the
level, live on every delivery, and the last path kept in local storage.
Icons are lapa's stored layers on the 100 grid, drawn as the board draws
them: a node's own `Iconed` part first, then its class's, then a drawing
the croquis keeps for the roots, which carry no icon yet. The level draws
from `Lapa.Access.icon`. The tag is two groups of the id's base64,
characters 8 and 9 for the minute at sixteen minute steps and 12 to 15 for
three random bytes, with the tenant in front only where it is not the
Account's own, since shares may one day cross tenants. Driven headless on
2026-09-27: Account, then Inbox, Personal and the Domain at `admin`; under
Personal the sections, minted in one moment; a reload opens on the kept
path. The root drawings belong in sylva's root batch once the roots take
an `Iconed` part.

The sylva side is its own session there, in this order: the push throttle,
then whatever the three questions above ask of the binding. Sylva's
`SESSION.md` is empty and gets its intention when that session opens.

## Technical
