# Contributing

This project follows the [épure](https://epuremethod.com) method, as the
sibling repository `../sylva` does. Its `CONTRIBUTING.md` is the source of
the method; this file says how the method lands here.

## Working agreement

1. **Scenarios define behavior.** Write or change the scenario before changing
   behavior. Use the audience's vocabulary. A bug needs a scenario that
   reproduces it.
2. **Keep one current design.** Remove temporary designs when the scenarios
   replace them. Record lasting reasons in `DECISIONS.md`: date, decision,
   rejected alternative, and cost. Do not use it as a work log.
3. **Passing checks complete the work.** The scenarios and standing checks
   must pass. Step definitions are production-quality code. An incorrect step
   can hide incorrect behavior.

`docs/content/pages/EDITOR.md` is the design: it settles the vocabulary, the
model, the input layer and the order of work. Read it before changing the
editor. What the editor is lives there; what it refused lives in
`DECISIONS.md`.

## Packages

One pnpm workspace. The root holds no code. The directory under `packages/`
is the package's own name: `packages/editor` is `@epure/editor`,
`packages/tilia` is `@tilia/editor`, and `packages/lapa` will be
`@lapa/editor`. The dependency runs one way, from the core out.

- `packages/editor/` is the core, package `@epure/editor`, namespace
  `Editor`: the types, the pure model, the notation, markdown in and out, and
  the storage port. It depends on nothing.
- `packages/tilia/` renders, package `@tilia/editor`, namespace
  `TiliaEditor`: React over contentEditable, input events into acts, the
  block views keyed by id through tilia. It is built here so that its shape
  can move, and migrates to tilia's own repository once it has settled.
- `packages/lapa/` will fill the port with rows, package `@lapa/editor`. It
  migrates to sylva once it has settled. Until sylva publishes the lapa
  packages it needs, it links to `../sylva/packages/*`.
- `docs/` builds the site with `@epure/minidoc`. The Operations page draws
  its cards from the core's fixtures, so a card and its test cannot drift
  apart.

`pnpm test` at the root runs every package's own `pnpm test`, and each of
those builds first. `pnpm dev` builds the packages and serves the site with
the demo.

## Scenarios

The scenarios are YAML fixtures under `src/design/`, run by `@epure/vitest`.
A fixture is a `feature` with a `background` naming its `given`, and
`examples`, one `scenario` each. Every scenario writes its document in the
notation described on the Operations page of `docs/`. The steps file beside
the fixtures binds each `given` and is production-quality code.

The text in every fixture comes from one course on topology: open sets,
closed sets, continuity, compactness, and on. The course needs what the
editor finds hard: inline math, LaTeX blocks, Greek and double-struck letters
composed from several keys, definitions and theorems as callouts, and
schemas. Do not write "hello world"; write a sentence the course would hold.

A scenario must be able to fail on the path it names. Keep a scenario title
to one action or assertion. Name the ids in a scenario only when the rule is
about identity.

The browser suite runs the same fixtures against the dev page through
Playwright, turning each act into keys. What no key can drive is skipped and
says so.

## Architecture

```
src/
  design/            fixtures, step bindings, world files
  domain/
    api/             types and signatures; no behaviour
    feature/         algorithms and real code
  view/              rendering, no business behaviour
```

`src/domain/` is the diagonal: `api/` declares and `feature/` implements,
and `api/` depends on no other layer. `src/view/` is a projection: it reads
the domain, and the domain reads no view. A `view/app` subdirectory holds
the dev page and the demo, and is a dev source. Lower layers never depend on
the test runner or views.

## Session order

One session handles one bounded goal.

1. Write `SESSION.md`: what will change, why, and who it serves.
2. Write the fixture with its scenarios.
3. Add the implementation approach and rejected alternatives to `SESSION.md`.
4. Bind the scenarios in the steps file.
5. Build until the scenarios and standing checks pass.

Stop after each stage and wait for agreement. Do not present several stages
as finished together. Do not write steps or build before the fixture is
agreed.

When the session is green, append only lasting decisions to `DECISIONS.md`,
bring the "Where it stands" section of `EDITOR.md` level with the code, and
clear `SESSION.md` back to its header. The scenarios remain.

## Writing

Write plain, natural English. Use common words, short sentences, active
voice, and concrete subjects. Put one claim in each sentence. Keep the
domain's exact vocabulary: document, section, block, run, mark, atom,
reference, atom, keyed array, port. Avoid metaphors, idioms and clever
phrasing.

Use comments only for a domain rule, an external quirk, or an invariant that
the code and types cannot express. Keep them beside what they describe. Do
not comment fixtures. Put lasting rationale in `DECISIONS.md`. Delete stale
comments after changing code.

## Library references

Before using a library, read its version-matched
`node_modules/<package>/llms.txt` or `README.md`. If the reference does not
describe an API, ask before using it.
