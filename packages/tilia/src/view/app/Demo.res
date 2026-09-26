// The site's demo: the dev page's section in the editor, mounted into the
// elements the "Try it" page provides. The site's stylesheet styles it.

open Course

let state = View.prepare(section)
let mint = mint(state)
let mintEntry = mintEntry(state)

ReactDOM.querySelector("#demo-editor")->Option.forEach(root =>
  ReactDOM.Client.createRoot(root)->ReactDOM.Client.Root.render(
    <View state section storage mint mintEntry types />,
  )
)

ReactDOM.querySelector("#demo-port")->Option.forEach(root =>
  ReactDOM.Client.createRoot(root)->ReactDOM.Client.Root.render(<Received />)
)
