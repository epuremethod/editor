# Operations

Every edit is a pure function on the model. This page shows each one as a
card: the document before, the act, and the document after. The cards are
drawn from the same YAML fixtures that `@epure/vitest` runs, under
`packages/model/src/design/operations/`, so a card and its test cannot drift
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
- An empty line is an empty block.
- The act is a word, with its argument in parentheses: `backspace`, `enter`,
  `input(For every ε| there is a δ.)`. Several acts make a list:
  `[enter, enter]`.

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
second half takes a new one.

{{splitOps}}

## Input

Input is the browser's input event. The argument is the block that holds the
focus, as the browser left it: its whole text, and the caret or selection
inside it. The model diffs the old text against the new one to find the span
that changed, so marks move with it. Typing, composition, dead keys and
autocorrect all land here.

{{inputOps}}
