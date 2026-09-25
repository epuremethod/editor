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
- An empty line is an empty block. A line that starts with `# ` is a heading
  block, and the hashes are not part of its text.
- Marks are inline markdown in one canonical form: `**bold**`, `_italic_`,
  `` `code` `` and `[text](href)`. A set of marks nests in one order, link
  outside, then bold, then italic, then code. Bold and italic never open or
  close on a space, and two runs of one of them parted by spaces alone are
  one run. A literal marker takes a backslash.
- The side of the caret at a marker says which marks are pending. `**open|**`
  types the next letter bold and `**open**|` does not. Empty markers around
  the caret, `**|**`, hold a pending mark in plain text.
- The act is a word, with its argument in parentheses: `backspace`,
  `delete`, `enter`, `bold`, `italic`, `code`, `link(/open-sets)`, `moveUp`,
  `moveDown`, `paste(...)` and `input(For every ε| there is a δ.)`. Several
  acts make a list: `[enter, enter]`. The two arrows, `->` and `<-`, are acts
  too. The argument of `input` is plain text: the browser knows no marks, so
  none are read in it. The argument of `paste` is a document in the notation,
  one line per pasted block.

The text of every scenario comes from one course on topology. The course
needs what the editor finds hard: inline math, LaTeX blocks, letters composed
from several keys, callouts and schemas.

A scenario is the document before, the act, and the document after:

```yaml
- scenario: backspace at the start of a paragraph joins it with the previous one
  before: |
    Hello world
    |Second one
  when: backspace
  after: |
    Hello world|Second one
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

{{marksOps}}

## Caret

An arrow moves the caret one character. At the end of a block it crosses to
the next one. At a mark boundary the first press changes side without moving
in the text, and the second press moves: `**open|**` becomes `**open**|`, and
typing there is not bold. One press crosses every mark that ends at the
caret. After typing, the pending marks are the ones the typed text took.
After a deletion they follow the character before the caret, so backspace
from outside a run lands inside it. Up and down depend on line layout and
belong to the view, not the model.

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
