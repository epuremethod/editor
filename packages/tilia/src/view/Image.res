// The image rule: the live atom is the image as far as the storage has
// brought it, and a binding gives the loader that moves it. An image this
// device uploads draws its file, with the upload over it. An image on its
// way down draws a placeholder of its size, with the download in its
// center. Once stored and on the device, it draws the image alone.

type meta = {
  record: string,
  object: string,
  width: int,
  height: int,
  title: string,
  description: string,
}

type upload =
  | Waiting
  | Offline
  | Sending
  | Saving
  | Retrying(string)
  | Stopped(string)

type download =
  | Offline
  | Receiving
  | Checking

type progress<'state> = {done: float, total: float, state: 'state}

type t =
  | Loading(string)
  | Uploading({record: string, meta: option<meta>, src: string, progress: option<progress<upload>>})
  | Downloading({meta: meta, progress: option<progress<download>>})
  | Missing(string)
  | Ready({meta: meta, src: string})

let share = ({done, total}: progress<'state>) =>
  total > 0.0 ? Math.round(done /. total *. 100.0)->Float.toInt : 0

let said = (progress: option<progress<upload>>) =>
  switch progress {
  | Some({state: Sending} as progress) => `Uploading ${Int.toString(share(progress))}%`
  | Some({state: Offline}) => "Waiting for the network"
  | Some({state: Saving}) => "Saving"
  | Some({state: Retrying(_)}) => "Trying again"
  | Some({state: Stopped(reason)}) => `Stopped: ${reason}`
  | Some({state: Waiting}) | None => "Waiting"
  }

type placement = {width: option<string>, rotate: option<string>}

let placement: Rule.codec<placement> = {
  decode: param => {width: param->Dict.get("width"), rotate: param->Dict.get("rotate")},
  encode: ({width, rotate}) =>
    [("width", width), ("rotate", rotate)]
    ->Array.filterMap(((key, value)) => value->Option.map(value => (key, value)))
    ->Dict.fromArray,
}

let ratio = (meta: meta) => `${Int.toString(meta.width)} / ${Int.toString(meta.height)}`

// An atom shrinks to its content, so a placeholder takes the image's own
// width, and the placement's when it has one.
let widthOf = (meta: meta, param: placement) =>
  switch param.width {
  | Some(width) => width
  | None if meta.width > 0 => `${Int.toString(meta.width)}px`
  | None => "100%"
  }

let render = (image: t, ~param: placement, ~display as _) =>
  switch image {
  | Loading(_) => <span className="image__placeholder" />
  | Uploading({meta, src, progress}) =>
    <span className="image__frame" style={{width: ?param.width}}>
      <img className="image" src alt={meta->Option.mapOr("", meta => meta.description)} />
      <span className="image__upload">
        <span className="image__state"> {React.string(said(progress))} </span>
        {switch progress {
        | Some({state: Sending} as progress) =>
          <span className="image__bar">
            <span className="image__sent" style={{width: `${Int.toString(share(progress))}%`}} />
          </span>
        | _ => React.null
        }}
      </span>
    </span>
  | Downloading({meta, progress}) =>
    <span
      className="image__placeholder"
      style={{aspectRatio: ratio(meta), width: widthOf(meta, param), maxWidth: "100%"}}>
      {switch progress {
      | Some({state: Receiving | Checking} as progress) =>
        let shared = share(progress)
        // A circle of radius 15.915 is 100 long, so the dash is the share.
        <span className="image__download" role="progressbar" ariaValuenow={Int.toFloat(shared)}>
          <svg className="image__ring" viewBox="0 0 36 36">
            <circle className="image__track" cx="18" cy="18" r="15.915" />
            <circle
              className="image__received"
              cx="18"
              cy="18"
              r="15.915"
              strokeDasharray={`${Int.toString(shared)} 100`}
            />
          </svg>
          <span className="image__share"> {React.string(`${Int.toString(shared)}%`)} </span>
        </span>
      | _ => React.null
      }}
    </span>
  | Missing(_) =>
    <span className="image__missing"> {React.string("This image is not available.")} </span>
  | Ready({meta: {description}, src}) =>
    <img className="image" src alt=description style={{width: ?param.width}} />
  }

let rule = (
  ~loader: (Rule.atom, t, t => unit) => unit,
  ~leave: option<Rule.atom => unit>=?,
): Rule.rule<t, placement> => {
  param: placement,
  first: atom => Loading(atom.text),
  loader,
  render,
  ?leave,
}
