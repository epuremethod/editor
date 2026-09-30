# Session

Step 1 of the session fills **Intention**, step 3 fills **Technical**. When
the session closes, any choice worth remembering is appended to
`DECISIONS.md` and this file is cleared back to exactly what you are
reading. See `CONTRIBUTING.md`.

## Intention

Started 2026-09-29. This session lets a reader paste an image into the demo.
The Images page of the site, `docs/content/pages/IMAGE.md`, holds the whole
design: the image is a record, the section holds an atom that names it,
and a storage binding fills a hook that the view declares. This session
builds the part that lives in this repository and needs no lapa.

The work serves the reader of a course, who pastes a figure beside the text
and sees it at once, while its bytes travel. It also serves the storage
binding, which receives an image as a record and never as bytes inside a
block.

### What changes

- `@epure/editor` gains `embed`: an atom in a new display block after the
  block that holds the caret, or in an empty paragraph that becomes the
  display block. It knows no image and serves any embed. Its cards go on the
  Operations page, in `embed.yaml`.
- `@tilia/editor` keeps one tilia `source` per image atom. Its setup calls
  the storage binding with the atom's text and a setter, so an image loads
  when its atom first draws. On a paste, the binding returns the atom, the
  view sets up its source and embeds it. The view draws each state the
  binding sets, and a widget edits the title and the description.
- The demo's storage binding keeps records and blobs in memory, and moves a
  pasted image's upload on a timer.

An embed that adds a block changes the block list, so it saves at once. An
embed into an empty paragraph keeps the block list, so it stays typed. The
rule in `Typed` covers both.

The browser suite cannot put a file on the clipboard with keys. The `embed`
cards are skipped there and say so.

### Out of scope

- The lapa storage binding, `@lapa/editor` over `@lapa/db`, and what the
  Images page lists under "What the storage binding offers". It follows
  sylva's root session, which adds `Section`, `Sized` and `Ordered`.
- Dropping, copying, a paste into another document, a caption, and a
  removed image's bytes. The Images page lists them under "Not yet".
- A paste that holds both text and an image. The image wins, as the text is
  most often the file's name.

## Technical
