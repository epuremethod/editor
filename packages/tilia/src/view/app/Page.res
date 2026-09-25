// The dev page: one section of the course in the editor, and under it what
// the port receives, so an act can be watched landing on the host.

open Editor

type shown = {mutable last: string}

let section: Section.t = {
  id: "open-sets",
  blocks: [
    (
      "a",
      "A **topology** on a set X is a collection τ of subsets of X, called _open sets_, such that:",
    ),
    ("b", "The empty set and X itself are open."),
    ("c", "Any union of open sets is open, and any finite intersection of open sets is open."),
    (
      "d",
      "See [compactness](/compactness) for what a finite subcover buys, and `U` for a typical open set.",
    ),
  ],
}

let shown = Tilia.tilia({last: ""})

let storage: Section.storage = {
  sections: [section],
  update: sections => {
    shown.last =
      sections
      ->Array.map(section =>
        section.blocks->Array.map(((id, text)) => `@${id} ${text}`)->Array.join("\n")
      )
      ->Array.join("\n\n")
  },
}

module Port = {
  @react.component
  let make = () => {
    TiliaReact.useTilia()
    <pre className="port" id="port"> {React.string(shown.last)} </pre>
  }
}

let state = View.prepare(section)

// The id a new block takes: the first letter no block holds, the way the
// model's harness mints, so a scenario that names ids reads the same here.
let letters = "abcdefghijklmnopqrstuvwxyz"
let mint = () => {
  let taken = state.doc.blocks->Array.map(block => block.id)
  let rec free = index => {
    let id = Notation.letter(index)
    taken->Array.includes(id) ? free(index + 1) : id
  }
  free(0)
}

// The hook a browser test drives: load a document in the notation, read it
// back in the notation.
type hook = {load: string => unit, notation: bool => string}
@set external expose: (Dom.window, hook) => unit = "editor"
@val external window: Dom.window = "window"

window->expose({
  load: source => View.load(state, Notation.read(source).doc),
  notation: labels => Notation.write(state.doc, ~labels),
})

module App = {
  @react.component
  let make = () =>
    <main>
      <h1> {React.string("open sets")} </h1>
      <View state section storage mint />
      <p className="label"> {React.string("what the port received")} </p>
      <Port />
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
