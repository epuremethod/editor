# Session

Step 1 of the session fills **Intention**, step 3 fills **Technical**. When
the session closes, any choice worth remembering is appended to
`DECISIONS.md` and this file is cleared back to exactly what you are
reading. See `CONTRIBUTING.md`.

## Intention

Started 2026-10-04. The Images page, `docs/content/pages/IMAGE.md`, is the
design. This session builds the radif side of an image paste in
`@radif/editor`: the code that makes an image record from a pasted file,
and the loader that brings an image from the record and its bytes. It then
wires both into the croquis, so that an image one person pastes shows in
the other person's editor.

The work serves the reader of a course who pastes a figure of an open
cover below the definition of a topology. The figure shows at once on
their screen, it is saved with the section, and it reaches everyone who
edits the course. It also serves the people who edit with them: a figure
pasted on another device arrives in their editor, first as a placeholder
of its size, then as the image.

### What changes

- `paste(file)` makes a row of `Image` under the document, as a draft.
  Its title is the file's name. Its width and height come from the
  decoded file. `client.bytes(~row, blob)` keeps the blob and answers the
  value of its `bytes` field. It returns the atom `{rule: "image", text:
  <the record's id>}` at once, and never waits for the save or the upload.
- The image has no `Attached`: the atom names it, and no list shows it.
- `image` is the loader of `Image.rule`. It reads the record, drafts
  included, and opens its bytes with `client.open_`. It sets `Loading`
  while the record has not arrived, `Missing` when the reader cannot
  reach it, `Uploading` while the blob is on this device and not yet
  stored, and `Ready` once the bytes are stored. An object URL is the
  image's `src`.
- The loader reads the record through the binding, so tilia runs it again
  when the record or its bytes change. A record that syncs in from
  another device moves the image on with no extra wiring.
- The croquis hands `~paste` to the view and `Image.rule(~loader=image)`
  to its rules. Two clients test it in Chrome: one pastes, and the image
  shows in the other's editor.

### Out of scope

- The description: writing it, and the draft becoming a record. The
  rule's editor with the title, the description, the width and the
  rotation is a session of its own.
- The upload's progress. Radif does not report it.
- `Downloading` with a percent, drop, copy, a paste into another
  document, and the bytes of a removed image.
- The website demo's in-memory binding.

### Depends on

The two-client test needs radif's fix for a push that carries edges
without their rows. Until it lands, the founder's first push is refused.
The binding's own scenarios do not need it.

### The fixture

`packages/radif/src/design/Images.feature`. It names what an image draws,
and not its states: while it loads, the blob when the device holds it and
a placeholder when it does not; once loaded, the stored image.

## Technical

### The image model

The five states of the Images page become three, after the rule the
fixture names:

```
Image.t =
  | Loading({record: string, meta: option<meta>, blob: option<string>})
  | Missing(string)
  | Ready({meta: meta, src: string})
meta = {width, height, title, description, object}
```

`Loading` draws the blob when it has one, a placeholder of the size when
it has the meta, and a placeholder of one line otherwise. `Missing` says
the image is not available. `Ready` draws the `<img>`. `object` is the
bytes' object key, so a loader that runs again on the same bytes keeps its
`Ready` and opens nothing.

`Atoms.feature` and its fake loader move to the three states. Its
`Downloading(r42, 800 × 400)` reads `Loading(r42, 800 × 400)`.

### The binding

`packages/radif/src/domain/feature/Images.res`:

```
Images.make(~client, ~binding, ~document, ~measure) => {paste, loader}
```

- `pasted: dict<string>` holds an object URL of each blob this device
  pasted, by row id. It lives as long as the binding.
- `paste(file)` answers `None` for a file whose type is not `image/…`.
  Otherwise it makes the `Image` row with `RadifStore.Image.make`, so the
  id is known at once, keeps `URL.createObjectURL(file)` in `pasted`, and
  answers `Some({rule: "image", text: id})`. Then, without waiting:
  `measure(file)` gives the width and height, `client.bytes(~row, file)`
  gives the `bytes` value, and one upsert writes the row as a draft.
- `loader(atom, previous, set)` sets `Loading` with the blob from
  `pasted` at once, before any read. It reads
  `RadifStore.Image.one->withDrafts->at(atom.text)` through the binding,
  which tilia tracks:
  - `Loading` or `NotSet`: `Loading`, with the blob if any.
  - `NoData(NoMatch)`: `Missing`.
  - `Loaded` with the row: if `previous` is `Ready` over the same
    `object`, it stays. Otherwise it sets `Loading` with the meta and the
    blob, and calls `client.open_(bytes)`. When that answers, and the
    atom's text is still the row's id, it sets `Ready`. The `src` is the
    pasted URL when there is one, so a pasted image never swaps its
    source and never blinks. Otherwise it is an object URL of the bytes
    read.
- `leave(atom)` revokes the pasted URL and removes it from `pasted`. The
  image rule gives it as its `leave`.
- `measure` is `createImageBitmap` in the browser. The steps pass the size
  the scenario names.

A row from another device arrives through the binding's pull, so tilia
runs the loader again and it opens the bytes.

### Leaving

`Rule.rule` gains an optional `leave: atom => unit`. `Live.sync` calls it
when an atom's id leaves the section, before it deletes the atom and its
live atom. `Image.rule(~loader, ~leave=?)` passes it on.

### The croquis

`opened` makes the binding with the document. The view gets
`~paste=images.paste`, and the rules get `("image",
Image.rule(~loader=images.loader))`.

### The steps

`packages/radif/src/design/ImagesSteps.res`, with vitest and
`@epure/vitest` in `@radif/editor`, in Node.

- A vitest global setup spawns `radif dev` on a temporary data directory,
  as `dev.mjs` does, and reads the founder's session from its first line.
- Ben's client is a real `Client` over a memory kv and memory blobs, with
  the server's URL as its base. His course is made as `opened` makes it.
- "Another device" is a second client of Ben's. What it writes reaches the
  first through a real pull.
- The wire of the reading client wraps `fetch`. It can hold the object
  reads until "its bytes arrive", and it can stop every request for "Ben
  is offline".
- "Draws" renders the rule's renderer with the live atom through
  `react-dom/server`, and reads the markup: an `<img>` and its `src`, or a
  placeholder.
- "The pasted file" is the URL in `pasted`. "The stored bytes" is an
  object URL of the bytes the bucket served.

### Rejected

- **A fake store in place of the client.** The fixture is about rows that
  sync and bytes that a bucket serves. A fake would test the fake.
- **Waiting for the size before answering the atom.** The paste would
  wait for a decode. The blob shows without the size.
- **Swapping the pasted blob for the stored bytes at `Ready`.** Radif
  stores each object under a customer key, so a read sends the key in its
  headers, and every image the browser shows from radif is an in-memory
  blob. The swap would download bytes the device holds, and free nothing.
  Radif drops its own kept copy when the push lands; the pasted URL is
  released when the image leaves the section.
- **Five states.** Rejected at first, since `Uploading` and `Downloading`
  differed only in a progress that radif does not report. Reversed on
  2026-10-05, see "Waiting on radif".

## Waiting on radif

### Where it stands, 2026-10-05

Stage 5 (build) is done, and the paste works in Chrome between Ben and
Aisha. Nothing is committed.

- tilia 6.0.1 fixed the loop in the record reader.
- The croquis opens on `ben.localhost` and `aisha.localhost`. radif signs
  each object read with `crypto.subtle`, which a plain http origin lacks.
- The croquis `merge` kept only what the remote held. A paste into an
  empty paragraph keeps the block list, so its atom stays unsaved for a
  second, and a row that landed then dropped it. The merge now keeps a
  local entry that neither the base nor the remote holds.
- The browser in the croquis shows the short id on the right, in the URL
  alphabet.

### The radif session

radif is adding progress for an upload and a download: the bytes done and
the total, for `client.bytes` and `client.open_`, and for an object by its
key, since an upload can finish after a reload.

### When radif finishes

1. Update `@radif/*` and check the croquis paste again.
2. Reopen the fixture, and stop for agreement. An upload and a download
   draw differently, so the image has five states again: `Loading`,
   `Uploading`, `Downloading`, `Missing`, `Ready`.
   - `Downloading` has no image yet: the placeholder at the image's size,
     with round progress in its center.
   - `Uploading` shows the image from its blob, with a small indicator at
     the bottom right.
   - The progress is optional in both, and drawn only when present.

   `Atoms.feature`, `Images.feature` and `IMAGE.md` move to the five
   states.
3. Build: the model, the loader, the steps and the view.
4. Close the session.
   - `DECISIONS.md`: the pasted blob stays the source. The swap to the
     stored bytes at `Ready` was refused.
   - `EDITOR.md`, near the port's `merge`: a host's merge must keep a local
     atom that neither the base nor the remote holds.
   - "Where it stands" in `EDITOR.md`.
   - Clear this file, and commit.

Still open in radif, with the croquis workarounds in `Collab.res`: the
back-query along `attached.parents`, `radif dev`'s bucket without CORS, a
read by id that answers "no match" offline, and a Node client that is not
told to pull.
