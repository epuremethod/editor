open RadifDb.App
open RadifDb.Data
open RadifDb.Wire
open Radif.Query

// The radif side of an image: `paste` makes a row of `Image` from a pasted
// file, and `loader` brings an image from its row and its bytes. A pasted
// image is a draft under the document, since it has no description yet,
// and carries no `Attached`: the atom names it. The blob of each image
// this device pasted stays on screen as its source, from the paste until
// the image leaves the section. Radif keeps every object under a customer
// key, so a stored image is an in-memory blob too, and a swap would only
// download bytes the device holds.

type t = {
  paste: TiliaEditor.View.paste,
  loader: (TiliaEditor.Rule.atom, TiliaEditor.Image.t, TiliaEditor.Image.t => unit) => unit,
  leave: TiliaEditor.Rule.atom => unit,
  /** An object URL of each blob this device pasted, by row id. */
  pasted: dict<string>,
}

@val @scope("URL") external createObjectURL: 'blob => string = "createObjectURL"
@val @scope("URL") external revokeObjectURL: string => unit = "revokeObjectURL"
@get external media: TiliaEditor.Browser.file => string = "type"
@get external name: TiliaEditor.Browser.file => string = "name"
@new external blobOf: (array<Uint8Array.t>, {"type": string}) => Blobs.blob = "Blob"

@val external later: (unit => unit, int) => unit = "setTimeout"

let outcome = (run: Reply.outcome<'a> => unit): promise<'a> =>
  Promise.make((resolve, reject) =>
    run({ok: resolve, error: message => reject(JsError.make(message))})
  )

// What a required `Bytes` field holds before the blob is kept.
let blank: Radif.bytes = {object: "", key: "", digest: "", size: 0.0, media: ""}

let make = (
  ~client: Client.t,
  ~binding: RadifTilia.t,
  ~document: Radif.id,
  ~measure: TiliaEditor.Browser.file => promise<(int, int)>,
): t => {
  let pasted: dict<string> = Dict.make()

  // A row is absent once the client is in step and no pull has brought
  // anything for `quiet` milliseconds. Before that, a row that does not
  // answer may still be on its way. The loader reads `inStep`, so it runs
  // again when the client comes back online.
  let quiet = 500
  let (inStep, setInStep) = Tilia.signal(false)
  let heard = ref(Date.now())
  let _ = client.synced(stepped => {
    heard := Date.now()
    setInStep(stepped)
  })
  let _ = client.receives(_ => heard := Date.now())
  // Each run of a loader, by atom id: a check that a later run overtook
  // sets nothing.
  let runs: dict<int> = Dict.make()

  // The row is made first, so its id answers the paste at once. The size
  // and the bytes come after, and one upsert writes the row.
  let paste = (file: TiliaEditor.Browser.file) =>
    if !(file->media->String.startsWith("image/")) {
      None
    } else {
      let row = RadifStore.Image.make(
        client.context,
        ~under=document,
        ~document={extension: file->media->String.sliceToEnd(~start=6)},
        ~file={bytes: blank},
        ~described={description: ""},
        ~sized={width: 0.0, height: 0.0},
        ~titled={title: file->name},
        ~draft={by: [{id: client.context.author, value: ""}], state: "draft"},
      )
      let id = row.entity.id
      pasted->Dict.set(id, createObjectURL(file))
      let written = async () => {
        let (width, height) = await measure(file)
        let bytes = await client.bytes(~row=id, Obj.magic(file))
        row.file = {bytes: bytes}
        row.sized = {width: Int.toFloat(width), height: Int.toFloat(height)}
        await outcome(reply => client.upsert([RadifStore.Image.record(row)], reply))
      }
      written()
      ->Promise.catch(error => {
        Console.error2("the pasted image was not written", error)
        Promise.resolve()
      })
      ->ignore
      Some({TiliaEditor.View.rule: "image", text: id})
    }

  let loader = (atom: TiliaEditor.Rule.atom, previous: TiliaEditor.Image.t, set) => {
    let id = atom.text
    let blob = pasted->Dict.get(id)
    let waiting = meta => TiliaEditor.Image.Loading({record: id, meta, blob})
    let run = runs->Dict.get(atom.id)->Option.getOr(0) + 1
    runs->Dict.set(atom.id, run)
    let current = () => runs->Dict.get(atom.id) == Some(run) && atom.text == id
    let row = switch binding.load(RadifStore.Image.one->withDrafts->at(id)) {
    | Loaded({data}) => Ok(Some(data))
    | NoData({reason: NoMatch(_)}) => Ok(None)
    | _ => Error()
    }
    let online = inStep.value
    let rec absent = () =>
      if current() {
        let silent = (Date.now() -. heard.contents)->Float.toInt
        silent >= quiet ? set(TiliaEditor.Image.Missing(id)) : later(absent, quiet - silent)
      }
    switch row {
    | Error() => set(waiting(None))
    // A pasted row is written once its size and bytes are known: until
    // then the blob stands for it.
    | Ok(None) if blob != None => set(waiting(None))
    | Ok(None) =>
      set(waiting(None))
      if online {
        later(absent, quiet)
      }
    | Ok(Some(row)) =>
      let meta: TiliaEditor.Image.meta = {
        record: id,
        object: row.file.bytes.object,
        width: row.sized.width->Float.toInt,
        height: row.sized.height->Float.toInt,
        title: row.titled.title,
        description: row.described.description,
      }
      switch previous {
      | Ready({meta: was, src}) if was.object == meta.object =>
        if was != meta {
          set(Ready({meta, src}))
        }
      | _ =>
        set(waiting(Some(meta)))
        if meta.object != "" {
          client.open_(row.file.bytes)
          ->Promise.thenResolve(read =>
            switch read {
            | Some(read) if current() =>
              let src = switch blob {
              | Some(src) => src
              | None => createObjectURL(blobOf([read.bytes], {"type": row.file.bytes.media}))
              }
              set(Ready({meta, src}))
            | _ => ()
            }
          )
          ->ignore
        }
      }
    }
  }

  let leave = (atom: TiliaEditor.Rule.atom) =>
    pasted
    ->Dict.get(atom.text)
    ->Option.forEach(url => {
      revokeObjectURL(url)
      pasted->Dict.delete(atom.text)
    })

  {paste, loader, leave, pasted}
}
