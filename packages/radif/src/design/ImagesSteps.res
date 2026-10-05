open EpureVitest
open RadifDb.App
open RadifDb.Data
open RadifDb.Wire
open Radif.Query

// Steps for Images.feature. Ben's clients are real ones over a memory kv
// and memory blobs, against the `radif dev` that `server.mjs` starts. Each
// scenario makes its own course. "Another device" is a second client of
// Ben's: what it writes reaches the first through a real pull. The first
// client's wire wraps the platform's fetch, and can hold the reads of an
// object until its bytes arrive. "Draws" renders the image rule's renderer
// to markup and reads it.

type radif = {base: string, session: string}
@module("vitest") external inject: string => radif = "inject"

@val external fetch: Fetch.t = "fetch"
@new
external file: (array<Uint8Array.t>, string, {"type": string}) => TiliaEditor.Browser.file =
  "File"
@new external encoder: unit => {"encode": string => Uint8Array.t} = "TextEncoder"
@new external blob: (array<Uint8Array.t>, {"type": string}) => Blobs.blob = "Blob"
@module("react-dom/server")
external markup: React.element => string = "renderToStaticMarkup"

let raise = message => JsError.throwWithMessage(message)

let outcome = (run: Reply.outcome<'a> => unit): promise<'a> =>
  Promise.make((resolve, reject) =>
    run({ok: resolve, error: message => reject(JsError.make(message))})
  )

let settle = ms => Promise.make((resolve, _) => setTimeout(() => resolve(), ms)->ignore)

// A step waits for the state it names, up to a bound. The expect after it
// says what stood.
let until = async (check: unit => bool) => {
  let rec wait = async left =>
    if !check() && left > 0 {
      await settle(20)
      await wait(left - 1)
    }
  await wait(250)
}

let bytesOf = (name: string) => encoder()["encode"](`the bytes of ${name}`)

// The wire of Ben's first client: it counts the pushes, and holds every
// read of an object while `holding` is set.
type wire = {
  wire: Fetch.t,
  mutable holding: bool,
  mutable held: array<unit => unit>,
  mutable pushes: int,
  mutable landed: int,
}

let wired = () => {
  let rec self = {
    wire: (href, init) => {
      let object =
        init.headers
        ->Option.flatMap(headers =>
          headers->Dict.get("x-amz-server-side-encryption-customer-key")
        )
        ->Option.isSome
      let pushing = href->String.includes("/push")
      if pushing {
        self.pushes = self.pushes + 1
      }
      let send = () =>
        fetch(href, init)->Promise.thenResolve(answer => {
          if pushing && answer.ok {
            self.landed = self.landed + 1
          }
          answer
        })
      if object && init.method_ != Some("PUT") && self.holding {
        Promise.make((resolve, _) =>
          self.held->Array.push(() => send()->Promise.thenResolve(resolve)->ignore)
        )
      } else {
        send()
      }
    },
    holding: false,
    held: [],
    pushes: 0,
    landed: 0,
  }
  self
}

let opens = async (~wire=?) => {
  let {base, session} = inject("radif")
  let client = await Client.make({
    base,
    token: session,
    kv: MemoryKv.make().kv,
    blobs: MemoryBlobs.make().blobs,
    ?wire,
  })
  let binding = RadifTilia.make(~client, ~clock=SystemClock.make())
  (client, binding)
}

let loaded = loadable =>
  switch loadable {
  | Radif.Loaded({data}) => Some(data)
  | _ => None
  }

let personalOf = async (client: Client.t, binding: RadifTilia.t) => {
  let read = () =>
    binding.load(Radif.under(RadifStore.Personal.klass)(client.actor))
    ->loaded
    ->Option.flatMap(personals => personals->Array.get(0))
  await until(() => read()->Option.isSome)
  switch read() {
  | Some(personal) => personal.entity.id
  | None => raise("Ben's client reaches no Personal node")
  }
}

let image = (binding: RadifTilia.t, id) =>
  binding.load(RadifStore.Image.one->withDrafts->at(id))

given1("Ben's course {string}", async (on, title: string) => {
  let wire = wired()
  let (client, binding) = await opens(~wire=wire.wire)
  on.test.onTestFinished(_ => client.close())
  let personal = await personalOf(client, binding)
  let course = RadifStore.Document.make(
    client.context,
    ~under=personal,
    ~document={extension: "course"},
    ~titled={title: title},
  )
  await outcome(reply => client.upsert([RadifStore.Document.record(course)], reply))
  let document = course.entity.id

  // The size each pasted file decodes to, by its name.
  let sizes: dict<(int, int)> = Dict.make()
  let images = Images.make(~client, ~binding, ~document, ~measure=pasted =>
    Promise.resolve(
      sizes
      ->Dict.get((Obj.magic(pasted): {"name": string})["name"])
      ->Option.getOr((0, 0)),
    )
  )

  // The atom a scenario follows, its live atom, and what the paste answered.
  let atom: ref<option<TiliaEditor.Rule.atom>> = ref(None)
  let live: ref<option<{"value": TiliaEditor.Image.t}>> = ref(None)
  let answered: ref<option<option<TiliaEditor.View.pasted>>> = ref(None)
  let pushedBefore = ref(0)

  // Ben's other device, and the rows it makes, by the name a scenario
  // gives them.
  let other: ref<option<(Client.t, RadifTilia.t)>> = ref(None)
  let rows: dict<RadifStore.Image.t> = Dict.make()
  let otherDevice = async () =>
    switch other.contents {
    | Some(opened) => opened
    | None =>
      let opened = await opens()
      let (device, _) = opened
      on.test.onTestFinished(_ => device.close())
      other := Some(opened)
      opened
    }

  let follow = (id: string) => {
    let followed: TiliaEditor.Rule.atom = Tilia.tilia({
      TiliaEditor.Rule.id: "f2",
      rule: "image",
      text: id,
      param: Dict.make(),
    })
    let held = Tilia.tilia({
      "value": Tilia.source(TiliaEditor.Image.Loading({record: id, meta: None, blob: None}), (
        previous,
        set,
      ) => images.loader(followed, previous, set)),
    })
    let _ = Tilia.observe(() => ignore(held["value"]))
    atom := Some(followed)
    live := Some(held)
  }
  let followed = () =>
    switch atom.contents {
    | Some(atom) => atom
    | None => raise("no atom names an image yet")
    }
  let value = () =>
    switch live.contents {
    | Some(held) => held["value"]
    | None => raise("no atom names an image yet")
    }
  let drawn = () =>
    markup(TiliaEditor.Image.render(value(), ~param={width: None, rotate: None}, ~display=false))
  let source = () =>
    switch drawn()->String.match(/<img[^>]* src="([^"]*)"/) {
    | Some([_, Some(src)]) => Some(src)
    | _ => None
    }
  let pastedUrl = () => images.pasted->Dict.get(followed().text)
  let idOf = name =>
    switch rows->Dict.get(name) {
    | Some(row) => row.entity.id
    | None => raise(`no row is named ${name}`)
    }
  let named = name => {
    let row = rows->Dict.get(name)
    switch (row, atom.contents) {
    | (Some(row), Some(atom)) if atom.text == row.entity.id => ()
    | _ => raise(`the atom does not name ${name}`)
    }
  }
  let imagesOfCourse = () =>
    binding.load(Radif.under(RadifStore.Image.klass)(document))->loaded->Option.getOr([])
  let pastedRow = () =>
    switch answered.contents {
    | Some(Some({text})) => image(binding, text)->loaded
    | _ => None
    }

  on.step("Ben is offline", () => client.offline())

  on.step(
    "Ben pastes the image {string} of {number} × {number} pixels",
    (name: string, width: int, height: int) => {
      sizes->Dict.set(name, (width, height))
      pushedBefore := wire.pushes
      let answer = images.paste(file([bytesOf(name)], name, {"type": "image/png"}))
      answered := Some(answer)
      answer->Option.forEach(({text}) => follow(text))
    },
  )
  on.step("Ben pastes the file {string}", (name: string) => {
    pushedBefore := wire.pushes
    answered := Some(images.paste(file([bytesOf(name)], name, {"type": "text/plain"})))
  })
  on.step("the push lands", async () => {
    await until(() => wire.landed > pushedBefore.contents && pastedRow()->Option.isSome)
    await until(() =>
      switch value() {
      | Ready(_) => true
      | _ => false
      }
    )
  })
  on.step("every read has answered", async () =>
    await until(() =>
      switch answered.contents {
      | Some(Some({text})) =>
        switch image(binding, text) {
        | Loaded(_) | NoData(_) => true
        | _ => false
        }
      | _ => true
      }
    )
  )
  on.step("the image leaves the section", () => images.leave(followed()))

  on.step("an atom names the row {string} that no pull has brought", async (name: string) => {
    let (device, _) = await otherDevice()
    rows->Dict.set(
      name,
      RadifStore.Image.make(
        device.context,
        ~under=document,
        ~document={extension: "png"},
        ~file={bytes: {object: "", key: "", digest: "", size: 0.0, media: ""}},
        ~described={description: "Two of the intervals cover [0, 1]."},
        ~sized={width: 0.0, height: 0.0},
        ~titled={title: name},
      ),
    )
    client.offline()
    follow(idOf(name))
  })
  on.step("an atom names the row {string}", async (name: string) => {
    let (device, _) = await otherDevice()
    rows->Dict.set(
      name,
      RadifStore.Image.make(
        device.context,
        ~under=document,
        ~document={extension: "png"},
        ~file={bytes: {object: "", key: "", digest: "", size: 0.0, media: ""}},
        ~described={description: "Two of the intervals cover [0, 1]."},
        ~sized={width: 0.0, height: 0.0},
        ~titled={title: name},
      ),
    )
    wire.holding = true
    follow(idOf(name))
  })
  on.step("the pull answers that {string} does not exist", async (name: string) => {
    named(name)
    await until(() =>
      switch value() {
      | Missing(_) => true
      | _ => false
      }
    )
  })

  let brings = async (~draft, name: string, title: string, width: int, height: int) => {
    named(name)
    let (device, _) = await otherDevice()
    let row = switch rows->Dict.get(name) {
    | Some(row) => row
    | None => raise(`no row is named ${name}`)
    }
    let bytes = await device.bytes(~row=row.entity.id, blob([bytesOf(title)], {"type": "image/png"}))
    row.file = {bytes: bytes}
    row.titled = {title: title}
    row.sized = {width: Int.toFloat(width), height: Int.toFloat(height)}
    if draft {
      row.draft = Some({by: [{id: device.context.author, value: ""}], state: "draft"})
    }
    await outcome(reply => device.upsert([RadifStore.Image.record(row)], reply))
    await until(() => device.status() == Clear)
    await client.online()
    await until(() =>
      switch value() {
      | Loading({meta: Some(_)}) | Ready(_) => true
      | _ => false
      }
    )
  }
  on.step(
    "a pull brings the image {string} titled {string} of {number} × {number} pixels",
    async (name: string, title: string, width: int, height: int) =>
      await brings(~draft=false, name, title, width, height),
  )
  on.step(
    "a pull brings the image draft {string} titled {string} of {number} × {number} pixels",
    async (name: string, title: string, width: int, height: int) =>
      await brings(~draft=true, name, title, width, height),
  )
  on.step("its bytes arrive", async () => {
    wire.holding = false
    let held = wire.held
    wire.held = []
    held->Array.forEach(release => release())
    await until(() =>
      switch value() {
      | Ready(_) => true
      | _ => false
      }
    )
  })

  on.step("the paste answers an atom of rule {string}", (rule: string) =>
    expect(answered.contents->Option.flatMap(answer => answer)->Option.map(({rule}) => rule)).toEqual(
      Some(rule),
    )
  )
  on.step("its text is the id of a new row of Image", async () => {
    await until(() => pastedRow()->Option.isSome)
    expect(pastedRow()->Option.map(row => row.entity.id)).toEqual(
      answered.contents->Option.flatMap(answer => answer)->Option.map(({text}) => text),
    )
  })
  on.step("the course holds an image draft", async (table: array<array<string>>) => {
    await until(() => pastedRow()->Option.isSome)
    let shown =
      pastedRow()->Option.map(row => (
        row.draft->Option.isSome,
        row.titled.title,
        Float.toString(row.sized.width),
        Float.toString(row.sized.height),
      ))
    let wanted = toRecords(table)->Array.map((row: {"title": string, "width": string, "height": string}) => (
      true,
      row["title"],
      row["width"],
      row["height"],
    ))
    expect(shown).toEqual(wanted->Array.get(0))
  })
  on.step("the pasted image has no parents", async () => {
    await until(() => pastedRow()->Option.isSome)
    expect(pastedRow()->Option.map(row => row.attached)).toEqual(Some(None))
  })
  on.step("the pasted image names bytes the device holds", async () => {
    await until(() => pastedRow()->Option.isSome)
    switch pastedRow() {
    | Some(row) =>
      let read = await client.open_(row.file.bytes)
      expect(read->Option.map(read => read.bytes)).toEqual(Some(bytesOf("cover.png")))
    | None => raise("the course holds no pasted image")
    }
  })
  on.step("nothing was pushed", async () => {
    await settle(100)
    expect(wire.pushes).toBe(pushedBefore.contents)
  })
  on.step("the paste answers nothing", () =>
    expect(answered.contents).toEqual(Some(None))
  )
  on.step("the course holds no image", async () => {
    await settle(100)
    expect(imagesOfCourse()).toEqual([])
  })

  on.step("before any read answers, the image draws the pasted file", () => {
    expect(pastedUrl()->Option.isSome).toBe(true)
    expect(source()).toEqual(pastedUrl())
  })
  on.step("the image draws the pasted file", () => {
    expect(pastedUrl()->Option.isSome).toBe(true)
    expect(source()).toEqual(pastedUrl())
  })
  on.step("the image is ready", () =>
    expect(
      switch value() {
      | Ready(_) => true
      | _ => false
      },
    ).toBe(true)
  )
  on.step("the pasted file is released", () =>
    expect(images.pasted->Dict.get(followed().text)).toEqual(None)
  )
  on.step("the image {string} draws a placeholder", (name: string) => {
    named(name)
    expect(drawn()->String.includes("image__placeholder")).toBe(true)
    expect(source()).toEqual(None)
  })
  on.step("the image {string} says it is not available", (name: string) => {
    named(name)
    expect(drawn()->String.includes("image__missing")).toBe(true)
  })
  on.step(
    "the image {string} draws a placeholder of {number} × {number}",
    (name: string, width: int, height: int) => {
      named(name)
      expect(drawn()->String.includes("image__placeholder")).toBe(true)
      expect(
        drawn()->String.includes(`aspect-ratio:${Int.toString(width)} / ${Int.toString(height)}`),
      ).toBe(true)
      expect(source()).toEqual(None)
    },
  )
  on.step("the image {string} draws the stored bytes", (name: string) => {
    named(name)
    let src = source()
    expect(src->Option.map(src => src->String.startsWith("blob:"))).toEqual(Some(true))
    expect(src == pastedUrl()).toBe(false)
  })
})
