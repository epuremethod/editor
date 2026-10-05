// The image rule: the live atom is the image as far as the storage has
// brought it, and a binding gives the loader that moves it. While it loads,
// an image draws the blob the device holds, or a placeholder; once loaded,
// the stored image.

type meta = {
  record: string,
  object: string,
  width: int,
  height: int,
  title: string,
  description: string,
}

type t =
  | Loading({record: string, meta: option<meta>, blob: option<string>})
  | Missing(string)
  | Ready({meta: meta, src: string})

type placement = {width: option<string>, rotate: option<string>}

let placement: Rule.codec<placement> = {
  decode: param => {width: param->Dict.get("width"), rotate: param->Dict.get("rotate")},
  encode: ({width, rotate}) =>
    [("width", width), ("rotate", rotate)]
    ->Array.filterMap(((key, value)) => value->Option.map(value => (key, value)))
    ->Dict.fromArray,
}

let render = (image: t, ~param: placement, ~display as _) =>
  switch image {
  | Loading({blob: Some(src), meta}) =>
    <img
      className="image"
      src
      alt={meta->Option.mapOr("", meta => meta.description)}
      style={{width: ?param.width}}
    />
  | Loading({meta: Some({width, height})}) =>
    <span
      className="image__placeholder"
      style={{aspectRatio: `${Int.toString(width)} / ${Int.toString(height)}`, width: ?param.width}}
    />
  | Loading(_) => <span className="image__placeholder" />
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
  first: atom => Loading({record: atom.text, meta: None, blob: None}),
  loader,
  render,
  ?leave,
}
