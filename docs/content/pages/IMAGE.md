# Images

A reader pastes an image into a section: a figure of an open cover, or a
schema of a proof. This page says where the image lives, how an image that
is already stored loads, and how a pasted image is added. The second case
reuses the first. It is a proposal. The section "What `storage/binding`
offers" lists what the design needs from the code that connects the editor
to its storage.

## The image is a record

An image is not text, and it does not live in the section. The storage
keeps it as a record of its own. With radif, the record is a row of the
root class `Image`, with these fields:

| Field | From | What it holds |
| --- | --- | --- |
| bytes | `File` | the file, as the storage names it: the object's key, the key that opens it, a digest, a size and a media type |
| title | `Titled` | the file's name |
| description | `Described` | the text a reader who cannot see the image reads |
| width, height | `Sized` | the size in pixels |

`Image` descends from `File`, which holds the bytes and requires `Titled`.
`Image` declares no field of its own. It requires `Described` and `Sized`.
Every field is required. A decorative image says that it is decorative.

A viewer that knows only `Sized` can size the space before the bytes
arrive. An app's own class, such as a `Photo`, descends from `Image`, and
the editor draws it as an image. A `Video` is a sibling of `Image`: it also
requires `Timed`, which holds its duration in seconds.

The section holds an atom of type `image`, and its text is the record's id.
The atom says where and how the section shows the image. The record says
what the image is. So the section never holds bytes, and any viewer that
knows the image record can draw it.

A section names its document through `Attached`. A pasted image carries no
`Attached`: the atom names it, and no list shows it. A photo that a reader
uploads to a project carries `Attached`, so the project's list shows it.

The storage may name the bytes by a key that changes, for example when an
upload is refused and starts again under a new key. The record takes the
new key. The section does not change, because it names the record and not
the bytes.

## The atom holds a text and a param

The section is a row of the root class `Section`. It stores its blocks and
its atoms as two lists. Each entry of a list has an id and a value. An atom
also has a param: an object of texts. On the wire, an entry takes its
shortest form: a bare id, `[id, value]`, or `[id, value, {param}]`.

```
blocks: array<entry<string>>     a list of Prose
atoms:  array<placed<string>>    a list of Text, with a param

["f1", "math\n\\bigcup_{i \\in I} U_i \\in \\tau"]
["f2", "image\nr42", {"width": "50%", "rotate": "90"}]
```

The atom's type rides on the first line of its text, as it does today. The
rest of the text is the source: the LaTeX of a formula, over as many lines
as it needs, or the id of an image record. The param is the placement: how
wide the image shows, or how it turns. Most atoms hold an empty param, and
an empty param writes nothing. The app owns the keys. Radif checks that the
param is an object of texts, and it reads no key. The rule of the atom's
type decodes and encodes it.

A block is `Prose`, and it merges word by word. An atom's text is `Text`,
and it merges whole: two readers who change a formula or an image
conflict, and no merge makes a formula nobody wrote. A param always merges
whole: it is replaced, never mixed. A reader who changes the image and one
who resizes it both land, since they change different parts of the entry.
Two who resize it conflict, and the local param stands.

Only a list takes a param, and only when its field's definition says
`param`. `atoms` says it, and the app reads it through `Radif.placed`.
`blocks` does not, and the app reads it through `Radif.entries`. The flag is
frozen with the definition, like `many`.

A section requires `Attached`, since it always sits in a document.
`Attached` has one field, `parents`, a list with a param. Each entry names a
parent, its value is the position, and its param is the app's. The sections
of a document are one indexed seek back along `parents`, in position order.
A section needs no title: its heading, when it has one, is a block. The
document is the root class `Document`, which requires `Titled` and takes
`Attached` when it sits in another document. Its `extension` says what it
opens as, such as `course`. The top document, the course, carries no
`Attached`.

The radif croquis stores the root `Document` and `Section`, and defines no
class of its own. The founder's client makes one Document under their
Personal node, and one Section under it whose `parents` names it. The port
carries the param: the croquis reads each atom's text and param, and writes
both back.

Four parts share the work:

- **`@epure/editor`** knows no image. It holds the atom like any other.
- **`@tilia/editor`** knows no image either. It follows the rule each type
  declares, and it knows nothing of what that rule loads.
- **`storage/binding`** is the code that fills the editor's storage port.
  It loads an image record, and it turns a pasted file into an atom.
- **`app`** is the top layer: the demo, or a course over radif. It declares
  the `image` rule, keeps the loading states and draws them.

## The layers

An image is drawn from seven layers. Each layer lies over the one below
it. Two of them are typed: they hold what the device has and the storage
does not have yet.

| Layer | What it holds | Who writes it | Who reads it |
| --- | --- | --- | --- |
| view | the rule's renderer and editor, over the live atom | `app` declares them | the reader |
| blob | the pasted file, typed over the bytes until they are stored | `storage/binding`, from `paste` | the renderer, before the bytes |
| bytes | the stored file, and how far its download is | the storage, after the upload | `storage/binding`, which fetches them for the renderer |
| image row | the record: title, description, size, and the name of the bytes | `storage/binding`; the rule's editor through it | the renderer, which draws a placeholder of that size |
| typed | the atom's text and param on screen, typed over the section row until it is saved | `@epure/editor` | `@tilia/editor`, which gives it to the loader |
| atom | `{type: image, text: <record id>, param: <placement>}` in the section row | `@epure/editor`, from the atom that `paste` returns | `@tilia/editor` |
| block | the display block that places the atom | `@epure/editor`, by `embed` | `@tilia/editor` |

The loader reads the three lower layers through the typed text. It fills
the live atom from the three upper layers of data: the image row, the
bytes and the blob. The renderer never reads a row.

`@epure/editor` manages a new text. A paste into an empty paragraph keeps
the block list, so the atom stays typed and is not saved at once. The
loader must read the text on screen, and not the saved row, or that image
would not load until the save.

The blob settles like typed text. It lies over the bytes while the upload
runs. Once the storage holds the bytes and the device has them, the blob
has nothing left to add, and `storage/binding` drops it.

## One rule per type

An image draws the way a formula draws. The host hands the view its rules
by name, and an atom names its rule on the first line of its text. A rule
holds a codec for the param, a first value, an optional loader, a renderer
and an optional editor:

```
rule<'a, 'p>:
  param:   dict<string> <=> 'p                                 decodes and encodes the placement
  first:   atom => 'a                                          the live atom before the loader sets
  loader:  (atom, 'a, set) => unit                             sets the live atom, with the previous one
  render:  ('a, ~param, ~display) => React.element             draws the atom, inline or as a display
  editor:  ('a, ~param, ~onChange, ~onClose) => React.element  opens under the atom on a click
```

The loader reads the atom's text, and never its param. The renderer and
the editor read the decoded param.

`'a` is the live atom, the app's model of the atom. Each rule has its own,
and only the rule knows what it is. The view hands the live atom to the
renderer, and to the editor when a click opens it. To `@tilia/editor`,
these are plain calls. It never waits, and it never reads a loading state.

`editor` is optional: a rule without one
enters the editor's box. Its two callbacks are:

```
onChange: {text?, param?} => unit    a new text, or a new param that replaces the old one
onClose:  unit => unit               closes the editor and gives the focus back
```

`onChange` goes through `@epure/editor`, like a typed letter. The change is
typed until the save, it can be undone, and it merges. A new file is not a
text: the editor hands it to `paste` first, and passes the record id it
returns.

`math` and `image` are two rules of the same shape:

| Rule | `'a` | first | loader | renderer | editor |
| --- | --- | --- | --- | --- | --- |
| `math` | the atom | the atom | none | KaTeX, inline or in display mode | none: it enters the box |
| `image` | the image model | `Loading(text)` | `image` from `storage/binding` | a placeholder, then the image, sized by the param | the title and the description, the width and the rotation |

### The editor holds stable objects

The core is a value: every act returns a new document, and its atoms are
new records. `@tilia/editor` holds the section in `Live`: the core's row
and document, one tilia object for each atom id, and one live atom for
each.

After every act, save and landing, `Live.sync` writes the new document
into the same objects:

- An atom keeps its object while its id stays in the section. A new text
  is written into it. Its param object is merged key by key: a changed
  value is set, a missing key is deleted, and an equal value is not
  written.
- A new id gets an atom object and a live atom. For a rule with a loader,
  the live atom is a tilia `source` whose setup is the loader:
  `source(first(atom), (previous, set) => loader(atom, previous, set))`.
  For a rule without one, it is `first(atom)`.
- An id that leaves the section loses its atom and its live atom.

So a change reaches only what reads the part that changed. A resize
writes a key of the param: the renderer draws again, and no loader runs.
A new text runs the loader again, since it read the text, and the loader
receives the previous live atom. An image loader keeps the old image on
screen until the new one is ready, so a replaced image does not blink,
and a renderer can animate the change with CSS. The loader also reads the
record and its bytes from the binding, so tilia runs it again when they
change.

`math` needs no loader: its live atom is the atom object, so a new formula
changes its text in place.

A loader runs when its live atom is first read, which is when it is first
drawn. The first value rarely shows. When the storage holds the record and
the bytes on the device, the loader calls `set` at once, in the same tick.

## Loading an image

A section arrives with an atom `{type: image, text: <record id>}`.

```flow An image already stored, drawn when its section opens
@tilia/editor | opens the section and builds a source for the atom
storage/binding | runs as the source's setup, with the record id on screen
@tilia/editor | hands the live image to the image renderer
storage/binding | fetches the record and the bytes, and sets each state it reaches
app | draws each state
```

A draw reads the source, so it runs again each time the loader sets. The
editor does not see the change. The image model is `Image.t` in
`@tilia/editor`:

```
image:
  Loading({record, meta?, blob?})   the row or its bytes are on their way
  Missing(record)                   no such row, or the reader cannot reach it
  Ready({meta, src})                the bytes are on the device
meta: {record, object, width, height, title, description}
```

- While it loads, an image draws the blob when the device holds it, a
  placeholder of its width and height when the row has arrived, and a
  placeholder of one line otherwise.
- `Missing` says that the image is not available.
- `Ready` draws the image, with the description as its text for a reader
  who cannot see it.

A row that does not answer may still be on its way: a client cannot tell
a row it has not pulled from a row that does not exist. So the radif
loader sets `Missing` only once the client is in step and no pull has
brought anything for 500 milliseconds. Offline, the image stays a
placeholder.

A click on an image opens the rule's editor. It writes the title and the
description to the record, and the new values come back through the
source.

## Pasting an image

A reader pastes an image file. The pasted image then loads the way a stored
one does. The only difference is that the bytes are already on the device.

The blob lives in the storage. It never lives in the editor or in the
atom. In the demo, it sits in a map in memory, under the record's id. With
radif, it sits in the client's blob store, `config.blobs`, under the
object's key. `client.bytes(~row, blob)` keeps the blob and answers the
value that the record's `bytes` field holds. The client uploads the blob
before the push that names it, and the push carries the value only.

```flow One pasted image, from the clipboard to the screen
@tilia/editor | reads the file from the clipboard and hands it to storage/binding
storage/binding | makes an image record, keeps the blob under its id, and returns an atom
@epure/editor | puts the atom in a display block, and the section is saved
@tilia/editor | builds a source for the atom, as for a stored image
storage/binding | sets Loading with the blob at once, then Ready once its bytes open
app | draws the blob from the first draw
```

- `paste(file)` makes the record and returns the atom at once. The editor
  never waits for the bytes or the save. The size and the bytes come
  after, and one upsert writes the row.
- `@epure/editor` gains one edit, `embed`. It puts an atom in a new display
  block after the block that holds the caret. An empty paragraph becomes the
  display block itself. `embed` knows no image and serves any embed: an
  image, a video, a quiz. Its cards are on the Operations page.

### The upload

The editor does not see the upload. The pasted blob is the image's `src`
from the first draw, so the image shows before any byte has left the
device. It stays the `src` once the bytes are stored: radif keeps every
object under a customer key, so a read sends the key in its headers, and
an image read back would be an in-memory blob of the same bytes. Radif
drops its own kept copy when the push that names it lands. The binding
releases the pasted blob when the image leaves the section.

A refused save starts the upload again. With radif, the client mints a new
object key, rewrites the record, and uploads again under that key. An
offline device uploads once it is back online. Nothing here is an error.
An image is local first, like the text around it.

### The description is required

A pasted image has a title, the file's name, but no description. So it
cannot be a complete record until the reader writes one. With radif, the
pasted image is a draft: a row of `Image` that carries the `Draft` part.
A draft is stored and synced, and it does not have to meet the record's
requirements yet. The row becomes a record when the reader writes the
description.

## The demo

The demo has no storage and no radif. It declares its own `image` rule, and
its `storage/binding` keeps the records and the blobs in memory. On a
paste, the binding reads the size from the decoded image and moves the
upload from 0 to 100 and on to `Ready` on a timer, so a
reader can watch the image travel. It stores nothing.

## What `storage/binding` offers

- `loader(atom, previous, set)`: sets the image that the atom's text
  names, and runs again whenever the row or its bytes change. It is the
  loader of the `image` rule.
- `leave(atom)`: releases the pasted blob of an image that left the
  section.
- `describe(text, ~title, ~description)`: writes the title and the
  description to the record. The rule's editor calls it.
- `paste(file)`: makes an image record from a file and returns its atom at
  once.

Radif already gives the binding what it stands on:

- the root classes `Document`, `Image` and `Section`, and the facets
  `Sized` and `Attached`;
- a list of atoms whose entries carry a param, read as `Radif.placed`;
- `client.bytes`, which keeps a pasted blob until the push that names it
  lands, and `client.open_`, which reads the kept blob or the stored bytes;
- a draft, which holds the bytes before the description is written.

Radif does not report how far an upload or a download has gone yet. A
progress bar waits for it.

## Not yet

- Dropping an image with the mouse, and copying an image out.
- Pasting an image into another document. The record is copied under the
  new section, and its bytes are copied with it.
- A caption, in the atom's param.
- A video. Its record is a `Video`, and its param holds where one embed
  starts and ends.
- A removed image. Its record stays until a sweep removes it, and its bytes
  stay with the record.
