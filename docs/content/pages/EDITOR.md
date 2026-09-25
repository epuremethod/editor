# The editor

The editor is a view over rows. A chapter of the course is a row, each of its
sections is a row, and a section holds its blocks in one field. Nothing is a
text blob. This page settles the words, what lives in the store, how two
copies of a section merge, and how the browser is kept out of the model. The
Operations page holds the contract, one card per edit.

Three packages share the work, and the dependency runs one way.
`@epure/editor` is the core: the types, the pure model, the notation,
markdown in and out, and one small storage port of plain data. It depends on
nothing, and it is the third instrument of the method beside `@epure/vitest`,
which runs the scenarios, and `@epure/minidoc`, which publishes them: this
one writes them. `@tilia/editor` renders: React over contentEditable, input
events into acts, the block views keyed by id through tilia. `@lapa/editor`
fills the port with rows and adds what only lapa can give: drafts, proposals,
sharing, a section in two documents.

## Vocabulary

A **document** is a row that orders sections. A chapter of the course is a
document. A book is a document too, with chapters under it in place of
sections, because a row may hang under a row of the same class.

A **section** is a row, and it is the unit of everything social. It is what a
person shares, drafts, proposes or transcludes. It is also the smallest thing
lapa syncs, merges and reaches on its own. A section keeps its content in one
field. The definition of a topology with its three axioms is a section. The
proof of a theorem is a section. A section has no heading level and no
nesting. Its heading, when it has one, is a block inside it.

A **block** is one entry of that field: an id and a content. It is the
smallest thing the editor renders, and the thing the Operations page draws one
line for. A block has a kind. A **paragraph** holds prose. A **heading** holds
a title. A **formula** holds a LaTeX display. An **embed** holds no text. It
names a row that hangs under the section, and that row draws itself. A video
block is an embed whose row is a Video, and a quiz block is an embed whose row
is a Quiz. Paragraph is the everyday word for the common block. The model says
block.

The content of a text block is **runs**: plain text and a list of **marks**. A
mark is a kind, such as bold, italic, code or link, over a span of the plain
text, counted in characters. The **caret** and the **selection** are offsets
in the same plain text, so they map onto the rendered text one to one.

The field that holds the blocks is a **keyed array**: an ordered list of
entries, each keyed by its id. The order is the array. An id never moves from
one content to another.

```schema A chapter, one of its sections, and what the section holds
Document Chapter 2, topological spaces
  Section Definition of a topology [position a0]
    a # Definition
    b A topology on a set X is a collection τ of subsets of X, called open sets, such that:
    c $$\emptyset \in \tau \quad\text{and}\quad X \in \tau$$
    d Any union of open sets is open. Any finite intersection of open sets is open.
    e ~ Video The three axioms, drawn
    Video The three axioms, drawn
  Section First examples [position a1]
    a The discrete topology holds every subset of X.
    b The indiscrete topology holds only ∅ and X.
```

## Rows and reach

Two things run through the tree above, and they are not the same thing. Reach
is the graph: an edge from the chapter to each section, and from a section to
the video it embeds. Structure is a relation: each section names its chapter
in its `parents` field, with a position beside the name. The graph says who
may see what. The relation says what comes before what. Neither does the
other's job.

Order lives on the child, not on the parent. A section's entry for a parent
holds a string position, a fractional key that always has room for one more
between two neighbours. The children of a chapter are one indexed hop back
along that relation, sorted by position. Inserting a section writes one row,
the section, and the edge that hangs it. The chapter row is not touched. This
is what lets a contributor with `append` add a section, and what lets a
proposed section place itself. It also means a reader who cannot reach a
section never receives its id, since the entry that orders it travels with the
section.

Sharing is one edge into the section. Whoever the edge reaches sees the
section and everything under it, so the video and the quiz come along without
another write. Transclusion is a second entry in `parents`: the same section,
in two chapters, at a position in each. The entries merge per parent, so a
move in one chapter and a share into another both survive.

```schema One section in two chapters, and the exercise it embeds
Document Chapter 2, topological spaces
  Section Exercise: is the cofinite topology Hausdorff? [position a3] [same row]
    a Let X be infinite and let τ hold ∅ and every set with finite complement.
    b ~ Quiz Pick two distinct points and try to separate them
    Quiz Pick two distinct points and try to separate them
Document Chapter 5, separation axioms
  Section Exercise: is the cofinite topology Hausdorff? [position a0] [same row]
```

## Inside a section

The keyed array is the section's whole content. A text block holds runs. An
embed holds a small dictionary: the id of the row it draws, the row's class,
and the parameters of its placement, such as a width or a caption. The row
holds the content, the video's file or the quiz's questions, in fields of its
own class with their own validation. Nothing is stored twice. The dictionary
says where and how the row appears. The row says what it is.

Ids are minted by the editor and never change. Enter splits a block, and the
first half keeps the id while the second half takes a new one. Backspace at
the start of a block joins it with the previous one, and the first id
survives. A move inside the section is a change of place in the array, with
the id untouched. These three rules are what makes the id something a later
merge can rely on.

An embed and its row have separate lifetimes. Deleting the embed leaves the
row under the section, so that undo can bring the block back and find its
row waiting. A row under a section that no embed names is dangling, and a
sweep or an explicit remove clears it. The other way round, a section whose
embed names a row that has not arrived yet draws a placeholder from the
dictionary's class, and fills it when the row lands.

```schema A text block, an embed, and the row the embed draws
Section Compactness
  a A space is compact when every open cover has a finite subcover.
  b ~ Video Covering the circle
  c Compactness is preserved by continuous images.
  Video Covering the circle [width wide] [caption The circle, covered by arcs]
```

## Merge

Lapa merges a record three ways against the base it keeps. A plain field
takes the newer stamp. A text field runs diff3, so two edits to different
places in one paragraph both land, and two edits to the same place surface as
a conflict with markers a person or an AI can read. The keyed array is the
third way, and it is the one piece of merge work this editor asks of lapa.

A keyed array merges as a sequence of ids first, and as texts second. Diff3
over the two sequences of ids against the base settles what was inserted,
deleted and moved. Then every id edited on both sides runs diff3 on its text.
An embed's dictionary merges field by field, like any record. So a conflict
lands on one block, not on the section, and the view can show it in place.

The shapes to name are few. Edited here and deleted there is a conflict.
Moved here and moved there is a conflict. Inserted at the same gap by both is
an interleave: the merge takes a fixed order, and a person fixes the order in
seconds. Two concurrent splits of one block at the same point produce two new
ids with the same text, one after the other. It is rare, it is visible, and
it is the price of an id that never drifts.

```flow From a keystroke to another reader's screen
runs | the block the editor holds while it has focus
keyed array | the section's one content field
record | one row, synced whole and merged against its base
binding | one tracked entry per block, keyed by id
view | only the block whose entry changed re-renders
```

A remote edit landing in the block that has focus is the delicate case. The
local runs stay the source while the block is focused. The merged text
arrives, a diff of the old text against the new gives an offset map, and the
caret moves through it. The typist never sees the caret jump.

## The port

The editor and its host meet at one boundary, and a section crosses it as a
list of blocks, each block its id and its text in canonical markdown. The
host stores strings and never sees a mark. The editor reads a block's
markdown into runs when it renders it, and writes runs back to markdown when
it hands the block out. Runs never leave the editor.

```schema What crosses the port: a section, one id and one markdown string per block
Section compactness
  a A space is compact when every open cover has a finite subcover.
  b **Compactness** is preserved by continuous images.
  c ~ Video Covering the circle
```

The port itself is two things, both plain data. The sections the host has
given the editor to edit, by id, and one call, `update`, that the editor
makes with the sections an act changed, whole, once per act. The core
observes nothing. Making a change re-render is the rendering binding's job:
it holds the sections in a tilia tree, re-reads a section the host wrote,
and re-renders the blocks whose entries changed. An in-memory store for
tests is the same port with `update` writing back into the sections.
Debouncing keystrokes is the host's choice, not the editor's.

```flow One act, from the key to the host
act | enter, a typed letter, bold over a selection
model | a pure edit on runs and offsets
section | the changed blocks written back as markdown
update | the host receives the section, whole
```

Embeds are opaque to the editor. An embed block is a fenced dictionary with
a type and parameters, rendered through a component the host injects for
that type. The editor never asks what the id means. The lapa binding
supplies the components that resolve it to a row.

## Files

Markdown is the file and interchange format, not the storage format. Pack
writes a section as plain markdown: a paragraph per block, a heading with its
hashes, a formula between double dollars, and an embed as a fenced block named
`lapa` that carries the row's id, its class and its placement. Block ids stay
out of the file, so the file a human or an AI edits stays clean. Unpack
matches the edited text back to ids by diff against the previous pack. A fence
with no id names a row that does not exist yet, so unpack mints the row from
the fence's class and parameters and writes the id back on the next pack.

Pack is canonical. The serializer has one form for each set of marks and one
order for the keys of a fence, so a hand-edited file that used another style
produces no merge noise once it has been through unpack and pack once.

## The input layer

The browser is an input device, not the model. Each block renders into a
contentEditable element that holds exactly the plain text of the block and
nothing else: no marker characters and no zero-width spaces. That keeps the
offset map one to one. The browser never mutates the DOM on its own.

Every input arrives as a `beforeinput` event and is intercepted, whatever its
type: typed text, a deletion backward or forward, a deleted word, a mark
toggle, a paragraph or line break, a paste, a replacement from autocorrect.
The edit is applied to the model, the event is prevented, the block is
re-rendered, and the selection is restored from model offsets. IME
composition is the one exception. The browser composes, and the text is read
back on `compositionend` and applied as one insert. The Operations page calls
this act `input`: the block as the browser left it, whole, with its caret. The
model diffs the old text against the new one to find the span that changed,
so marks move with it, and typing, composition, dead keys and autocorrect all
land on the same edit.

Every edit is a pure function on the model. Insert text, delete a range,
toggle a mark, set a link, split a block, join two blocks, move a block,
delete across blocks. No function touches the DOM, and every one of them is
tested with no browser.

## Marks

A mark extends when the caret types at its end, if the mark is bold, italic
or code. A link does not extend at its end, and no mark extends at its start.
Cmd+B on a caret stores a pending mark that applies to the next typed
character. An empty run never exists in the model, which is why the DOM never
needs a zero-width space to hold one.

Marks do not apply inside a code span. Toggling a mark over a range that
contains a code span skips the span. Overlapping marks are fine in the model.
Markdown cannot say them, so the serializer splits at every boundary, emits
each segment with its full set of marks, and merges adjacent segments whose
sets are equal.

Bold and italic never open or close on a space, in the model as in the file,
because CommonMark refuses `**bold **`. Two runs of one of them parted by
spaces alone are one run. So typing a space at the end of a bold run leaves
the space plain and keeps bold pending, and the next letter rejoins the run
across it. A code span and a link keep their edges, since a space inside them
is content.

## Across blocks

One `selectionchange` listener on the document is enough. Each block root
carries its id in a data attribute, and the listener resolves the anchor and
focus nodes of the selection to their blocks and offsets. Each block is then
in one of three states: not selected, partially selected between two offsets,
or fully selected. The listener computes the new state of every block and
updates only the blocks whose state changed.

Arrow up on the first line of a block moves to the previous block at the same
horizontal position. Arrow down on the last line moves to the next. A delete
over a selection that spans blocks trims the first block, trims the last,
deletes the blocks between and joins the two ends.

A selection that leaves a single block enters block-selection mode. Browsers
handle a selection across separate editable elements badly, so in that mode
the editor draws the selection itself.

## Copy and paste

Copy writes the selection twice: as markdown in `text/plain` and as rendered
marks in `text/html`. Paste reads `text/html` first and falls back to
`text/plain`. Both parse into blocks and runs. A paste that yields one block
inserts text and marks at the caret. A paste that yields several blocks
splits the current block: the first pasted block joins the text before the
caret, the last joins the text after, and the rest sit between as new
blocks.

A paste inside the same section is a change to one keyed array. A paste into
another document must clone the rows its embeds name under the new section,
because a reference alone may point at a row the reader of the new document
cannot reach. Pasting a book is thousands of blocks, hundreds of sections and
a few rows for its videos in one batch, and the batch must be comfortable.

## Undo

Undo is an editor stack of model edits, one per session. Browser undo breaks
across re-renders and across rows. Each entry stores the inverse edit and the
selection before it, so undo restores both the text and the caret.

## Testing

The model is pure and is tested with no browser. A corpus of markdown round
trips to runs and back without change: escapes, code spans, links with
brackets in their text, nested and overlapping marks, empty lines. Property
tests apply random sequences of edits and check that every mark stays inside
its text, that offsets stay ordered, and that a split followed by a join gives
back the original. Cross-block operations run against a fake list of blocks
before any row exists. The browser layer gets a few end-to-end tests on
`beforeinput`, composition and cross-block selection, in Chrome, Safari and
Firefox.

The hard parts stay hard. Escapes and code spans in the serializer and parser:
a literal asterisk, a bracket inside link text, a mark that must stop at a
code span. Canonical form against diff3 noise. IME composition and Safari
selection quirks.

## Roads not taken

One row per paragraph was the first design. It gives every paragraph an id
in the store, and that is all it gives. Each paragraph would be a node with
stamps, a position and a target for share edges. A pull would descend one
node per paragraph, a share of an exercise would need one edge per member,
and every Enter would be a graph write. The keyed array keeps the id and
drops the node.

A keyed array on the chapter, ordering its sections, would work once the
sequence merge exists. It loses anyway. Adding a section would need `edit`
on the chapter instead of `append`, a reader would receive the ids of
sections they cannot reach, every structural change by anyone would rewrite
one hot row, and a removed section would leave its id behind. Positions on
the child have none of these costs.

A character-level CRDT inside a block buys live co-typing in one paragraph
and nothing else. Its state is opaque, every edit must go through the
library, and a hand-edited file breaks it. Diff3 on a block is enough.

Float positions run out after about fifty inserts in one gap, and a rebalance
rewrites every sibling, which is a stop-the-world batch in a local-first
design. String keys extend instead.

Ids in the packed text would make the file a human edits unclean. Identity
lives in the row. YAML in a text field would make structured data prose. An
embed's placement is a dictionary that merges as fields, and the row's
content is fields of its class.

## Open

Bullet points. Where a list is one paragraph block and where each item is its
own block. The previous answer was to split into blocks past ten items.

The evaluator trigger on a relation change, sibling of the trigger on an
`under` edge, is a cost to schedule on the lapa side.

## Order of work

The order follows the difficulty. Row work is easy: positions, the `parents`
relation with its metadata, diff3 on a text field, the sorted hop back. Edits
inside a block are medium and need very good functional testing. Cross-block
work is medium: one selection watcher, fixed attributes per block, one
callback that updates only what changed. Copy and paste is medium hard,
because it is many block updates and row inserts in one batch. Inline edits
with marks are hard, because editing inside a text block while honouring
links, bold, italic and the rest is not trivial.

```flow The stages, in order
inline model | edits, the round-trip corpus and the property tests
block list | split, join, move, delete across, the paste result
one block in React | beforeinput, composition, selection restore
across blocks | cross-block selection and block-selection mode
copy and paste | both clipboard formats, the paste batch
undo | the stack of inverse edits
lapa | the keyed array, its sequence merge, rows bound through the port
```
