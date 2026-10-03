# Session

Step 1 of the session fills **Intention**, step 3 fills **Technical**. When
the session closes, any choice worth remembering is appended to
`DECISIONS.md` and this file is cleared back to exactly what you are
reading. See `CONTRIBUTING.md`.

## Intention

Started 2026-09-29, rescoped 2026-09-30 to the core. The Images page,
`docs/content/pages/IMAGE.md`, is the whole design. An image is a record in
the storage. The section contains an atom of type `image` whose text is the
record's id, and whose param says how the section places it. This session
builds the part of that design that belongs to `@epure/editor`. It knows
no image: what it gains serves any atom that a rule loads and places.

The work serves the reader of a course, who pastes a figure of an open
cover below a paragraph and then makes it half as wide. It also serves the
code that fills the port, which receives a placement as data beside the
atom's text and never has to parse it out of the text.

### Why the core carries the param

The core never learns what a param means. It carries the param for three
reasons, and none of them is a format:

- The core writes sections whole. A save rebuilds every atom from the
  document, so an atom without its param would lose it on each save. The
  host could add it back after each save, but it has nothing to add for an
  atom that was just pasted.
- A resize is an edit like a typed letter. It stays typed until the save,
  it can be undone, and it merges. The typed text and the three-way merge
  work on the sections the core writes, so the param must be in them.
- A pasted reference copies its atom under a new id. The copy keeps the
  param, or a copied image loses its width.

How a param is written to a file is the storage binding's choice. A
markdown binding writes an image in its own form, as it writes math
between dollars, and reads the param from the port like the text.

### What changes

- An atom gains a param: a dictionary of texts that the app owns. The core
  stores it, compares it and writes it, and never reads a key. Most atoms
  have an empty param.
- The port carries the param. An atom crosses as its id, its text and its
  param. An empty param writes nothing, so a section without one crosses
  as it does today.
- `embed` puts a new atom in a new display block after the block that
  contains the caret. An empty paragraph becomes the display block itself.
  The code that fills the port mints the atom; the core only places it.
- `place` replaces the param of an atom and changes no block. It is the
  core's side of a rule's editor that resizes or turns an image.
- A param is typed like a text. A `place` keeps the block list, so it
  waits for the host's save. An `embed` into an empty paragraph keeps the
  block list too. An `embed` that adds a block saves at once.
- A fixture's atom may name its param. The notation of the Operations
  page says so, and the `embed` and `place` cards go on that page.

The browser suite cannot put a file on the clipboard with keys. It skips
the `embed` cards and says so.

### Out of scope

- The rule per type in `@tilia/editor`, the carved section and its live
  atoms, and the demo's storage binding. They are the next session.
- The radif storage binding over `@radif/db`: `Radif.placed`, `client.bytes`
  and the `Image` draft. It follows the demo.
- Dropping, copying, a paste into another document, a caption, and a
  removed image's bytes. The Images page lists them under "Not yet".
- A paste that contains both text and an image. The image wins, as the
  text is most often the file's name.

## Technical

### The model

`Doc.atom` gains a required field, `param: dict<string>`. An atom with no
param has an empty dict. The field is required, so an empty param has one
form, and the structural equality that `Typed`, the view and the fixtures
use keeps working.

`Section.atom` becomes a record, `{id, text, param}`, in place of the pair
`(id, text)`. It has the fields of `Radif.placed<string>`, `{id, value,
param}`, so the radif binding maps one to the other field by field. The core
still depends on nothing. `Section.block` stays a pair.

### The port

`Storage.readAtoms` and `Storage.writeAtoms` carry the param. The type
is still the first line of the text, so `readAtom` and `writeAtom`
do not change. The atoms stay sorted by id.

`Typed.differs` compares a whole entry by its id, so an atom whose param
differs from the row is typed, as one whose text differs is. `Typed.act`
does not change: `place` keeps the block list, so it waits for the host's
save.

### The edits

- `Edit.place(doc, ~id, ~param)` replaces the param of one atom. An id the
  document does not contain returns the document as it was.
- `Edit.embed(doc, ~atom, ~block, ~type_, ~text)` takes two ids that the
  caller mints: one for the atom and one for a new block. It closes the
  box. It takes the block where the selection ends, in document order. An
  empty paragraph becomes a display block that contains the reference and
  keeps its id. Any other block stays whole, and a new display block with
  the id `block` goes after it. The caret lands after the reference, with
  the marks `Runs.placed` gives, as in `insert`. The new atom has an empty
  param.
- `paste` needs no change. It copies an adopted atom whole, so the copy
  keeps the param.

### The steps

- `operations/steps.res` reads a fixture atom with an optional `param`, and
  an absent one reads as an empty dict. `embed(type, text)` mints an atom
  id with `mintAtoms` and a block id with `mint`.
  `place(id, key=value, key=value)` reads the pairs after the first comma.
- `StorageSteps.res` reads a fixture atom as a string, or as `{text,
  param}`. A string is an atom with an empty param. `canonicalAtoms` reads
  the same way.
- `TypedSteps.res` reads an optional `param` column of `key=value` pairs,
  and it binds "the person places atom {string} at {string}".
- The browser suite drives only the acts it knows, so it skips the `embed`
  and `place` cards and says so. It needs no change.

### Outside the core

The type change reaches three places, and each change stays small:

- `@tilia/editor`: `Course.res` writes its atoms and its three-way merge
  over records. `Page.res` fills an empty param for an atom that the dev
  page loads without one. The view reads `type_` and `text` and never the
  param, so it does not change.
- `@radif/editor`: the croquis maps `Radif.placed` to the port and back,
  param included. The side table in `Collab.res` that restores each param
  after a save goes, and its comment goes with it.
- `docs/src/operations.mjs`: the list of atoms under a card shows each
  param, or a `place` card would draw the same before and after.

### Rejected

- **The param inside the text**, as a line after the type. A text merges
  whole, so a reader who resizes an image would conflict with one who
  changes it. The Images page says that both land.
- **The param outside the core**, in a table the host keeps. A save drops
  it, a paste loses it, and a resize is neither typed nor merged. The
  croquis does this today, and this session removes it.
- **An optional field, `param?`.** Absent and empty would be two forms of
  one value, and every equality would have to treat them as one.
- **A triple, `(id, text, param)`**, beside the block pair. A record
  names its fields and matches `Radif.placed`.
- **`embed` as `split`, `insert` and `display` in a row.** A split cuts the
  sentence at the caret, and an empty paragraph would take a new block
  instead of becoming one.
- **A param argument on `edit`.** `edit` sets the text and moves the box's
  caret. `place` does one thing and touches neither.

### One scenario to drop

With a required dict, "an empty param writes nothing" in `Storage.yaml`
cannot fail. An empty dict goes in and an empty dict comes out, whatever
the code does. It would test something only if the port wrote the
shortest form, and that form is radif's wire, not the core's port.
