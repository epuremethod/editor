# Operations

Every edit is a pure function on the model. This page shows each one as a
card: the document before, the act, and the document after. The cards are
drawn from the same YAML fixtures that `@epure/vitest` runs, under
`packages/editor/src/design/operations/`, so a card and its test cannot drift
apart.

## The notation

A fixture writes a document in a small notation. One line is one block, and
the text of the line is the block's text.

```text
Hello world
|Second one
```

- `|` is the caret. `{` and `}` hold a selection, and the two may sit in
  different blocks.
- A line may start with `@a ` to name its block. A line that names none gets
  a letter by position: `a`, `b`, `c`. Name the ids when the rule is about
  identity. When the `after` of a scenario names none, ids are not compared.
- A backslash keeps the character after it literal: `\|`, `\{`, `\}`, `\\`
  and `\@`.
- An empty line is an empty block. A line that starts with `# `, `## ` or
  `### ` is a heading block, and one that starts with `- ` is an item of a
  list. The prefix is the block's form, not part of its text. A line that
  must begin with such a prefix as text takes a backslash.
- Marks are inline markdown in one canonical form: `**bold**`, `_italic_`,
  `` `code` `` and `[text](href)`. A set of marks nests in one order, link
  outside, then bold, then italic, then code. Bold and italic never open or
  close on a space, and two runs of one of them parted by spaces alone are
  one run. A literal marker takes a backslash.
- The side of the caret at a marker says which marks are pending. `**open|**`
  types the next letter bold and `**open**|` does not. Empty markers around
  the caret, `**|**`, hold a pending mark in plain text.
- The act is a word, with its argument in parentheses: `backspace`,
  `delete`, `enter`, `bold`, `italic`, `code`, `link(/open-sets)`,
  `heading(2)`, `paragraph`, `item`, `display`, `moveUp`, `moveDown`,
  `paste(...)`, `insert(math, U \in \tau)`, `edit(a8f1, U \in \tau)` and
  `input(For every ε| there is a δ.)`. Several
  acts make a list: `[enter, enter]`. The two arrows, `->` and `<-`, are acts
  too. The argument of `input` is plain text: the browser knows no marks, so
  none are read in it. The argument of `paste` is a document in the notation,
  one line per pasted block.
- A scenario may carry `entries`, the section's dictionary beside its
  blocks: an id, a type and a text. `entriesAfter` says what it holds after
  the act, and when absent the entries are not compared. An entry the act
  mints takes `e1`, then `e2`. A pipe in an entry's text is the caret of
  the box under its atom, so the box is open on that entry at that offset.
  The course writes a literal bar as `\lvert` or `\mid`.
- An id between double braces in a line, such as `{{`a8f1`}}`, is a
  reference: characters of the plain text under a mark of its own. It is
  read before the selection markers, so a selection may open right before
  one and close right after it. A line that starts with `:: ` is a display
  block, which holds one reference alone. A card draws a reference as the
  editor does, the entry rendered by its type, and never as its characters.

The text of every scenario comes from one course on topology. The course
needs what the editor finds hard: inline math, LaTeX blocks, letters composed
from several keys, callouts and schemas.

A scenario is the document before, the act, and the document after:

```yaml
- scenario: backspace at the start of a paragraph joins it with the previous one
  before: |
    Hello world.
    |Second one
  when: backspace
  after: |
    Hello world. |Second one
```

## Join

Backspace at the start of a block joins it with the previous one. The first
block keeps its id.

{{joinOps}}

## Split

Enter splits the block at the caret. The first half keeps the id and the
second half takes a new one. Over a selection, the selection goes first.

{{splitOps}}

## Delete

Delete removes the character after the caret. At the end of a block it joins
the next block onto it, the mirror of backspace, and the caret stays where it
was. Over a selection, delete and backspace both remove it. A selection
across blocks trims the first block, trims the last, drops the blocks
between and joins the two ends. The first id survives.

{{deleteOps}}

## Input

Input is the browser's input event. The argument is the block that holds the
focus, as the browser left it: its whole text, and the caret or selection
inside it. The model diffs the old text against the new one to find the span
that changed, so marks move with it. Typing, composition, dead keys and
autocorrect all land here.

{{inputOps}}

## Marks

A mark extends when typing reaches its end, unless it is a link. No mark
extends at its start. A toggle over a selection adds the mark to all of it or
removes it from all of it, keeps the selection, and skips any code span. On a
caret a toggle stores a pending mark for the next typed character.
Punctuation typed at the end of a run lands outside it, so a sentence that
ends on a bold word or a code span ends plain. A space typed at the end of a
bold run keeps the run pending, so the next word rejoins it; a space typed
at the end of a code span lands outside, since a span is one identifier.
The keys are Cmd+B, Cmd+I and Cmd+E.

{{marksOps}}

## Caret

An arrow moves the caret one character, and at the end of a block it
crosses to the next one. Wherever it lands, by arrow or by click, the caret
takes the marks of its place: inside a bold, italic or code run at its end,
outside a link at its end, outside any run at its start. Cmd+B takes the
other side. After typing, the pending marks are the ones the last typed
character took. After a deletion they follow the character before the
caret. Up and down depend on line layout and belong to the view, not the
model.

{{caretOps}}

## Move

A block moves one place at a time. The blocks a selection covers move
together. Ids and offsets do not change, so the selection travels with them.

{{moveOps}}

## Paste

One pasted block goes into the text at the caret. Several split the block:
the first pasted block joins the text before the caret, the last joins the
text after, both the way a join does, and the rest sit between as new
blocks. The caret lands at the end of what was pasted. Over a selection, the
selection goes first.

{{pasteOps}}

## Heading

A block has a form: prose, a heading with its level, or an item of a list.
The form is the line's prefix on the port and in the notation, and it is not
text in the model. Setting a form a block already has turns it back into
prose, so one key toggles. On a split the form follows the text: the half
that holds the title stays a heading, and an empty half is prose. Backspace
at the start of a heading turns it into prose and does not join; the next
backspace joins.

{{headingOps}}

## Item

An item splits into two items, so a list goes on. Enter on an empty item
leaves the list, and backspace at the start of an item turns it into prose.

{{itemOps}}

## Reference

A reference holds an entry in a block: the id between double braces, under a
mark of its own. The editor draws it as an atom, the entry rendered by its
type, and the browser may not edit it. The caret never sits inside an atom.
What the arrows do at one is the type's to say. A type that enters, such as
a formula, opens its box: right before the atom opens it with the caret at
the start of the source, and left after the atom opens it at the end. Inside
the box the arrows move through the source, and at its edges they leave it,
after the atom on the right and before it on the left. Escape leaves after
the atom. A type with a widget of its own, such as a video, is skipped whole,
and so is a reference to no entry. Typing beside an atom lands outside it,
and a mark toggled over a range that holds one covers it whole. Backspace
after an atom selects it, and delete before one does the same, so nothing
invisible is ever removed; the next backspace removes it and leaves its
entry in the section. `edit` changes the text of an entry and no block, and
in an open box it leaves the caret after what was typed. `insert` mints an
entry and places its reference at the caret; in the editor it is Cmd+M, and
the box takes the source. A pasted reference copies its entry under a new
id, so two references never share one entry by accident, and a reference to
an entry the section does not hold stays as it is.

{{referenceOps}}

## Display

A display is a block form, beside paragraph, heading and item: it holds one
reference alone and draws it as a block. A formula on its own line is a
display, and the same formula in a sentence is inline; the entry is the same
and its type says how it draws in each place. Only a block holding one
reference alone takes the form, and a block that no longer does, after any
edit, is prose again. Backspace at the start of a display joins it to the
paragraph above and its atom lands inline. Enter at its end opens a
paragraph under it. In the editor the form is Cmd+Alt+4.

{{displayOps}}
