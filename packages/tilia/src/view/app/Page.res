// The dev page: one section of the course in the editor, and under it what
// the port receives, so an act can be watched landing on the host.

open Editor
open Course

let state = View.prepare(section, ~rules)
let mint = mint(state)
let mintAtom = mintAtom(state)
let collaborator = Collaborator.make(section)

// An atom as a fixture writes it. An atom without a param has an empty one.
type given = {@as("type") type_: string, text: string, param?: dict<string>}

// The hook a browser test drives: load a document in the notation with its
// atoms, read it back in the notation, and read its atoms.
type hook = {
  load: (string, Nullable.t<dict<given>>, Nullable.t<Doc.editing>) => unit,
  notation: bool => string,
  atoms: unit => dict<Doc.atom>,
  editing: unit => Nullable.t<Doc.editing>,
}
@set external expose: (Dom.window, hook) => unit = "editor"
@val external window: Dom.window = "window"

window->expose({
  load: (source, atoms, editing) =>
    View.load(
      state,
      {
        ...Notation.read(source).doc,
        atoms: atoms
        ->Nullable.toOption
        ->Option.getOr(Dict.make())
        ->Dict.mapValues((atom): Doc.atom => {
          type_: atom.type_,
          text: atom.text,
          param: atom.param->Option.getOr(Dict.make()),
        }),
        editing: editing->Nullable.toOption,
      },
    ),
  notation: labels => Notation.write(View.doc(state), ~labels),
  atoms: () => View.doc(state).atoms,
  editing: () => View.doc(state).editing->Nullable.fromOption,
})

module App = {
  @react.component
  let make = () =>
    <main>
      <h1> {React.string("open sets")} </h1>
      <View state storage mint mintAtom />
      <Collaborator.Toggle sim=collaborator state storage />
      <p className="label"> {React.string("what the port received")} </p>
      <pre className="port" id="port">
        <Received />
      </pre>
    </main>
}

let style = `
  :root { color-scheme: light; --black: #000; --grey: #6b6b6b; --faint: #f1f1f1; --red: #e2231a; }
  body { margin: 0; font-family: Jost, Helvetica, Arial, sans-serif; font-size: 1.15rem; line-height: 1.5; color: var(--black); background: #fff; }
  main { max-width: 46rem; padding: 3rem 2rem; }
  h1 { font-size: 3rem; font-weight: 700; letter-spacing: -0.04em; margin: 0 0 2rem; }
  h1::after { content: ""; display: block; width: 5rem; height: 0.5rem; margin-top: 1rem; background: var(--red); }
  .editor { outline: none; caret-color: var(--red); border-top: 2px solid var(--black); padding-top: 1rem; }
  .editor p { margin: 0 0 1rem; min-height: 1.5em; }
  .editor code { font-family: "IBM Plex Mono", monospace; font-size: 0.85em; background: var(--faint); padding: 0.05em 0.3em; }
  .editor a { color: var(--black); text-decoration: underline; text-decoration-color: var(--red); text-decoration-thickness: 2px; }
  .atom { display: inline-block; cursor: pointer; border-radius: 2px; }
  .atom:hover { background: var(--faint); }
  .atom:empty, .atom .math:empty { min-width: 1em; min-height: 1em; }
  .atom--display { display: block; text-align: center; padding: 0.5rem 0; }
  .atom__missing { font-family: "IBM Plex Mono", monospace; font-size: 0.85em; color: var(--red); }
  .source { font-family: "IBM Plex Mono", monospace; font-size: 0.85em; }
  .box { z-index: 10; background: #fff; border: 2px solid var(--black); box-shadow: 0 4px 16px rgba(0,0,0,0.12); padding: 0.4rem; }
  .box__source { display: block; width: 24rem; min-height: 1.6em; font-family: "IBM Plex Mono", monospace; font-size: 0.85rem; border: none; outline: none; resize: vertical; }
  .widget { z-index: 10; background: #fff; border: 2px solid var(--red); box-shadow: 0 4px 16px rgba(0,0,0,0.12); padding: 0.4rem; }
  .widget__source { display: block; width: 24rem; font-family: "IBM Plex Mono", monospace; font-size: 0.85rem; border: none; outline: none; }
  .video { font-family: "IBM Plex Mono", monospace; font-size: 0.85em; background: var(--faint); padding: 0.05em 0.3em; }
  .collaborator { margin: 2rem 0 0; font-size: 0.85rem; color: var(--grey); }
  .collaborator__last { display: block; margin-top: 0.3rem; font-family: "IBM Plex Mono", monospace; font-size: 0.75rem; }
  .label { margin: 3rem 0 0.5rem; font-size: 0.72rem; font-weight: 500; letter-spacing: 0.3em; text-transform: uppercase; color: var(--grey); }
  .port { margin: 0; padding: 1rem 1.2rem; background: var(--faint); font-family: "IBM Plex Mono", monospace; font-size: 0.8rem; white-space: pre-wrap; min-height: 3rem; }
`

@val @scope("document") external head: Dom.element = "head"
@val @scope("document") external createElement: string => Dom.element = "createElement"
@set external textContent: (Dom.element, string) => unit = "textContent"
@send external append: (Dom.element, Dom.element) => unit = "append"

let sheet = createElement("style")
sheet->textContent(style)
head->append(sheet)

ReactDOM.querySelector("#root")->Option.forEach(root =>
  ReactDOM.Client.createRoot(root)->ReactDOM.Client.Root.render(<App />)
)
