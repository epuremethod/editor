# editor

A block editor over sections of markdown, written for a course on topology.
The model is pure and the browser is kept out of it. The Operations page of
the documentation is the contract: one card per edit, each read from the
same fixture the tests run.

The site is published at <https://epuremethod.github.io/editor/>.

## Packages

- `@epure/editor` holds the types, the pure model, the notation and the
  storage port. It depends on nothing.
- `@tilia/editor` renders the model with React over contentEditable, the
  block views keyed by id through [tilia](https://tiliajs.dev).
- `docs` builds the site with `@epure/minidoc`.

## Run it

```sh
pnpm install
pnpm test
pnpm dev
```

`pnpm dev` builds the packages and serves the documentation, with the demo,
at <http://127.0.0.1:62924/index.html>. It rebuilds when a page or a fixture
changes.

## Read first

`docs/content/pages/EDITOR.md` settles the vocabulary, the model, the input
layer and the order of work. The fixtures under `packages/editor/src/design/`
are the editor's contract, and every scenario writes its document in the
notation described on the Operations page.

## Credits

Built with [tilia](https://tiliajs.dev), [ReScript](https://rescript-lang.org),
[React](https://react.dev), [KaTeX](https://katex.org),
[Vitest](https://vitest.dev) and [@epure/vitest](https://epurejs.dev), which
runs the scenarios the way the [épure method](https://epuremethod.com)
writes them.
