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

Stop after each stage the user marks. Show the stage and wait for
agreement. Agents commit only when asked.
