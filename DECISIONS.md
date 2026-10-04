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

## 2026-09-26 — The second field of a section is `atoms`

Supersedes the word entry in "An entry is stored, and a reference names it",
above; the rule itself stands. An atom is the stored type and text, and the
piece drawn from them, the way a block is the stored line and the drawn
paragraph. The fields of a section are `blocks` and `atoms`.

Refused: `entries`. Lapa names every element of a many-field an entry, so a
block is an entry and the second field was a list of entries, and every
sentence about the binding had to say which one it meant.

Costs the design page one noun less between a source and its rendering,
which the words "text" and "draws" now carry.

## 2026-09-27 — An arrival merges through the port, at arrival

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

## 2026-09-27 — Typed text is a read, not a value

The editor holds the current row and the displayed document. The typed
text is what the document holds that the row does not, in the document's
order. A save writes the document and makes it the row; a landed row
becomes the row and the merge's answer becomes the document.

Refused: a dictionary of typed text keyed by id, with a list of ids for the
order. The document already holds both, and the dictionary was a second
copy to keep level.

Costs a write of the document and a comparison against the row on every
read of the typed text.

## 2026-09-27 — Save timing follows the resulting block list

An act whose result keeps the same ids in the same order is typing, and
the host decides when to save it. Any other result saves at once: a join,
a split, a move, a removal, a paste of several lines. The word is `typed`;
a draft is lapa's, a stored row with the Draft facet.

Refused: a save on every act. A keystroke is not a save, and `@tilia/query`
and lapa both model an explicit write. Refused: naming the acts that save.
A paste saves or not by its shape.

Costs the host one call, `save`, and the tilia binding a way to expose it.

## 2026-09-30 — An atom carries a param the core never reads

An atom is `{id, text, param}`, and the param is a required dictionary of
texts that the app owns. The core stores it, compares it, writes it through
the port and copies it on paste. It never reads a key. `place` replaces it
whole and keeps the block list, so it waits for the host's save.

Refused: the param inside the text, as a line after the type. A text merges
whole, so a reader who resizes an image would conflict with one who changes
it. Refused: the param in a table the host keeps. A save dropped it, a paste
lost it, and a resize was neither typed nor merged. Refused: an optional
`param?`. Absent and empty would be two forms of one value.

Costs every atom an empty dictionary, and every fixture atom with a param
the `{text, param}` form.

## 2026-09-30 — `embed` places a new atom in a display block

`embed` takes an atom id and a block id that the caller mints. An empty
paragraph becomes the display block and keeps its id. Any other block stays
whole, and the new display block goes after it.

Refused: `embed` as `split`, `insert` and `display` in a row. A split cuts
the sentence at the caret, and an empty paragraph would take a new block
instead of becoming one.

Costs the caller two ids, and the browser suite skips the card: no key
puts a file on the clipboard.

## 2026-10-04 — The view holds each atom as one stable object

`Live.sync` writes every new document into the same tilia objects: one
for each atom id, with its rule, its text and its param. The param object
is merged key by key. A resize then reaches only the renderer, and a
replaced image can change in place with a CSS transition.

Refused: new atom objects from each document. Every act would draw every
atom again, and a renderer could not tell a moved image from a new one.
Refused: live state in a React hook. A rebuilt block remounts its atoms,
and the state would be lost.

Costs a merge after every act, and identity that holds only for what the
view writes. Tilia hands out a new wrapper for a live value whose observer
left and came back, so an image's live state is equal, not identical,
after its atom draws again.

## 2026-10-04 — A loader is the setup of a tilia source

A rule's live atom is `source(first(atom), (previous, set) =>
loader(atom, previous, set))`. Tilia runs the loader again when a value it
read changes: the atom's text, or the record and the bytes it reads from
the binding. It receives the previous live atom, so an image keeps the old
one on screen until the new one is ready.

Refused: one loader call for each id, with the loader's own `observe` on
the text. Each loader would track its own reads and return a stop for the
editor to keep. Refused: a loader that takes the text alone. It could not
keep the previous image, and a new text would blink.

Costs a loader that answers late a check that the text it started from is
still the atom's text.

## 2026-10-04 — An atom names its rule

The host hands the view a dict of rules, and an atom names its rule on
the first line of its text. A rule decodes the param, gives a first value,
loads, draws and, optionally, edits. A rule without an editor enters the
box. The core's `type_` keeps its name for now.

Refused: `spec` with `render`, `enter` and `widget`. Three ways to say what
a click does, and no place for a loader or a param.
