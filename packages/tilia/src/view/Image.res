// The image rule: the live atom is the image as far as the storage has
// brought it, and a binding gives the loader that moves it.

type meta = {record: string, width: int, height: int, title: string, description: string}

type t =
  | Loading(string)
  | Missing(string)
  | Downloading(meta)
  | Uploading(meta, string)
  | Ready(meta, string)

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
  | Loading(_) => <span className="image__placeholder" />
  | Missing(_) => <span className="image__missing"> {React.string("This image is not available.")} </span>
  | Downloading({width, height}) =>
    <span
      className="image__placeholder"
      style={{aspectRatio: `${Int.toString(width)} / ${Int.toString(height)}`, width: ?param.width}}
    />
  | Uploading({description}, src) | Ready({description}, src) =>
    <img className="image" src alt=description style={{width: ?param.width}} />
  }

let rule = (~loader: (Rule.atom, t, t => unit) => unit): Rule.rule<t, placement> => {
  param: placement,
  first: atom => Loading(atom.text),
  loader,
  render,
}
