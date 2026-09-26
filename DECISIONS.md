# Decisions

Append-only, at the end, and never edited. An entry is an account of a moment,
not a description of the system, which is why it cannot go stale. To reverse a
decision, append a new entry naming the one it supersedes.

An entry gives the date, the choice, the alternative refused, and what the
choice costs, when there is a real cost. If it cannot name an alternative, it
is not a decision: leave it out. Keep it short. The reader is as smart as the
writer. What the editor is lives on the design page; what it refused lives
here.

## 2026-09-26 — An entry is stored, and a reference names it

A block holds `{{id}}` under a mark of its own, and the source lives in a
dictionary beside the blocks, one type and one text per entry. Every type
the host adds is one entry in a registry, and the parser never changes.

Refused: a table of verbatim spans in the text, each with an open and a
close, so that `$…$` and a music notation would be rows of one table. Every
new notation would have been a parser change, and a source in the line is
what the browser must not edit.

Costs a file its ids for a type with no inline form, unpack a diff to match a
dollar span back to its entry, and paste the entries it must carry along.

## 2026-09-26 — Display is a block form

A display holds one reference alone and draws it as a block. The type is
the same inline and on its own line, and the renderer takes the place as a
flag.

Refused: a `displaymath` type. The source is the same, and a person moves a
formula out of a sentence without changing what it is.

Refused: the rule that a reference alone in its block draws as a display.
An item or a one-word answer holding only a formula would have had no way
out, and the port could not tell the two apart.

Costs a form that constrains its content, and a settle step after every
edit that turns a display back into prose when its atom is no longer alone.

## 2026-09-26 — The type rides on the first line of an entry's text on the port

An entry crosses the port as an id and one string, the type on the first
line and the source after, and the core splits and joins them, the way it
reads a block's form off its prefix. The host stores strings and never reads
a type.

Refused: a third field on every list entry in lapa, for the sake of one.

Refused: the host reading the first line. The block side spared the host
its prefixes, and an entry should cost it no more.

Costs a conflict marker that may land on the type line, which the renderer
then shows as the error atom, and a type the host cannot index.

## 2026-09-26 — The box's caret is the model's; a widget's state is the view's

The document carries which entry is being edited and where its caret sits.
The box under an atom is that state drawn, so the arrows into and out of it
are cards. A type's own widget is opened and placed by the view, and only
its edits reach the model.

Refused: the box as view state alone, which no card could say.

Costs the document a field, every act that places a selection its closing
of the box, and the notation a pipe inside an entry's text.

## 2026-09-26 — The type says what the arrows do at an atom, by its widget

A type with `render` alone enters the editor's box: right before the atom
opens it at the start of the source, left after it at the end, and the edges
of the source leave it. A type with a widget is skipped whole. `enter: false`
skips and opens nothing.

Refused: always skipping, with a click as the only way in. A formula in a
sentence is typed through, not clicked.

Refused: an `enter` flag with no widget slot, which would have forced every
type that does not enter to be read-only.

Costs the core a predicate for the arrows, since it knows no type.

## 2026-09-26 — Paste copies an entry under a new id for every reference

A pasted reference to an entry the section holds is rewritten to a fresh
copy of it. A reference to an entry the section does not hold stays as it
is.

Refused: two references sharing one entry. Editing one would edit both, and
nobody who copied a formula expects that.

Costs paste one minted id per reference, and a section identical entries.

## 2026-09-26 — A zero-width space stands on each side of an atom

Chrome holds no caret beside a non-editable element at the edge of a block
unless a text node stands there. The view writes one on each side of every
atom, and the browser bindings count it as nothing.

Refused: no scaffolding. The caret was lost after a display and before an
atom that opens a block, and the model's selection could not be placed.

Costs the bindings a character to skip in every count, and the page's rule
that a paragraph holds exactly its text one exception.

## 2026-09-26 — The docs transform reads a fixture by name

Minidoc renders a `file` var as a template before its transform sees it, so
the double braces of a reference in a fixture read as its variables. Every
operations group is a `value` naming the fixture, and the transform reads
the file itself.

Refused: escaping the braces inside the fixtures. They are the contract, and
nothing in them is written for the site.

Costs the site config a name in place of a path, and a build error that
names the transform rather than the file.
