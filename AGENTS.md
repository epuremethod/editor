Read `CONTRIBUTING.md` before changing the project. It holds the épure
method as it lands here, shared with `../radif`.

Read `docs/content/pages/EDITOR.md` before changing the editor. It settles
the vocabulary, the model, the input layer and the order of work.

The fixtures under `packages/editor/src/design/` are the editor's
contract. Every scenario writes its document in the notation described on
the Operations page of `docs/`.

The text in every fixture comes from one course on topology: open sets,
closed sets, continuity, compactness, and on. The whole editor is tested
against that course, because it needs what the editor finds hard: inline
math, LaTeX blocks, Greek and double-struck letters composed from several
keys, definitions and theorems as callouts, and schemas. Do not write
"hello world"; write a sentence the course would hold.

Write plain, natural English. Use common words, short sentences, active
voice, and concrete subjects. Put one claim in each sentence. Keep a
scenario title to one action or assertion.

Use comments only for a domain rule, an external quirk, or an invariant that
the code and types cannot express. Do not comment fixtures. Put lasting
rationale in `DECISIONS.md`. Delete stale comments after changing code.

A session follows the order in `CONTRIBUTING.md` and keeps its state in
`SESSION.md`. Stop after each stage. Show the completed stage and wait for
agreement. Do not write steps or build before the fixture is agreed.

Agents commit only when asked. Never run `git push`, `git merge`,
`git rebase`, or `git reset`. Otherwise leave changes in the working tree.
