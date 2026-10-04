// The site's demo: the dev page's section in the editor, mounted into the
// elements the "Try it" page provides. The site's stylesheet styles it.

open Course

let state = View.prepare(section, ~rules)
let mint = mint(state)
let mintAtom = mintAtom(state)
let collaborator = Collaborator.make(section)

ReactDOM.querySelector("#demo-editor")->Option.forEach(root =>
  ReactDOM.Client.createRoot(root)->ReactDOM.Client.Root.render(
    <View state storage mint mintAtom />,
  )
)

ReactDOM.querySelector("#demo-collaborator")->Option.forEach(root =>
  ReactDOM.Client.createRoot(root)->ReactDOM.Client.Root.render(
    <Collaborator.Toggle sim=collaborator state storage />,
  )
)

ReactDOM.querySelector("#demo-port")->Option.forEach(root =>
  ReactDOM.Client.createRoot(root)->ReactDOM.Client.Root.render(<Received />)
)
