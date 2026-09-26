// The `operations` transform: a YAML fixture of `@epure/vitest`, rendered as
// one card per scenario. Each card draws the document before the act and the
// document after it, read with the model's own notation reader, so the page
// shows exactly what the test reads. The transform takes the fixture's name
// and reads the file itself: a fixture is a contract, and the double braces
// of a reference in it are not minidoc's variables.

import {readFileSync} from "node:fs"
import katex from "katex"
import {parse} from "yaml"
import {read} from "@epure/editor/src/domain/feature/Notation.res.mjs"
import {slugify} from "./markdown.mjs"

function escape(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
}

// The part of the selection that lands in one block: a caret offset with
// its pending marks, or the range the block holds of it.
function within(doc, block) {
  const selection = doc.selection
  if (!selection) return {}
  const index = id => doc.blocks.findIndex(candidate => candidate.id === id)
  const [start, stop] = [selection.anchor, selection.focus].sort(
    (a, b) => index(a.block) - index(b.block) || a.offset - b.offset,
  )
  if (start.block === stop.block && start.offset === stop.offset) {
    return start.block === block.id ? {caret: start.offset, pending: selection.pending} : {}
  }
  const here = index(block.id)
  const from = index(start.block)
  const to = index(stop.block)
  if (here < from || here > to) return {}
  const length = block.content.text.length
  return {
    range: [here === from ? start.offset : 0, here === to ? stop.offset : length],
  }
}

// A mark's kind, as the model compiles it: a string, or a link with its
// href, or a reference with its id.
const rank = {Link: 0, Bold: 1, Italic: 2, Code: 3, Ref: 4}
const name = kind => (typeof kind === "string" ? kind : kind.TAG)
const initial = {Bold: "B", Italic: "I", Code: "`", Link: "K"}

// An atom, drawn the way the editor draws it: a formula through KaTeX,
// inline or in display mode by its block's form, any other type as its
// source, and a reference to no entry as itself. The card shows what the
// person sees, never the source in the line.
function atom(id, entries, display) {
  const entry = entries[id]
  const inner =
    entry === undefined
      ? `<span class="tree__missing">${escape(`{{${id}}}`)}</span>`
      : entry.type === "math"
        ? katex.renderToString(entry.text.replace("|", ""), {displayMode: display, throwOnError: false})
        : `<span class="tree__source">${escape(entry.text.replace("|", ""))}</span>`
  return `<span class="tree__atom${display ? " tree__atom--display" : ""}">${inner}</span>`
}

function wrap(mark, inner, {entries, display}) {
  switch (name(mark.kind)) {
    case "Bold":
      return `<strong>${inner}</strong>`
    case "Italic":
      return `<em>${inner}</em>`
    case "Code":
      return `<code>${inner}</code>`
    case "Ref":
      return atom(mark.kind._0, entries, display)
    default:
      return `<a href="${escape(mark.kind._0)}">${inner}</a>`
  }
}

const covering = (marks, at) => marks.filter(mark => mark.start <= at && at < mark.stop)
const sameSet = (a, b) => a.length === b.length && a.every(kind => b.some(other => name(other) === name(kind)))

// The caret, with the marks it holds when they are worth showing: at a mark
// boundary, or when they differ from the character before it.
function caretHtml(content, at, pending) {
  const before = at > 0 ? covering(content.marks, at - 1).map(mark => mark.kind) : []
  const boundary = content.marks.some(mark => mark.start === at || mark.stop === at)
  const shown = boundary || !sameSet(pending, before)
  const label = pending.length ? pending.map(kind => initial[name(kind)]).join("") : "–"
  return `<span class="tree__caret"></span>${shown ? `<span class="tree__pending">${label}</span>` : ""}`
}

function text(doc, block, entries = {}) {
  const content = block.content
  const context = {entries, display: block.form === "Display"}
  const {caret, pending, range} = within(doc, block)
  const cuts = new Set([0, content.text.length])
  content.marks.forEach(mark => cuts.add(mark.start).add(mark.stop))
  if (caret !== undefined) cuts.add(caret)
  if (range) cuts.add(range[0]).add(range[1])
  const offsets = [...cuts].sort((a, b) => a - b)
  let html = ""
  offsets.forEach((at, index) => {
    if (range && at === range[1]) html += "</mark>"
    if (caret === at) html += caretHtml(content, at, pending)
    if (range && at === range[0]) html += '<mark class="tree__range">'
    const next = offsets[index + 1]
    if (next === undefined) return
    const marks = covering(content.marks, at).sort((a, b) => rank[name(b.kind)] - rank[name(a.kind)])
    html += marks.reduce((inner, mark) => wrap(mark, inner, context), escape(content.text.slice(at, next)))
  })
  return html
}

// A block's form, drawn as the prefix the notation writes for it.
function lead(block) {
  const form = block.form
  if (form === "Item") return '<span class="tree__form">- </span>'
  if (form === "Display") return '<span class="tree__form">:: </span>'
  if (typeof form === "object") return `<span class="tree__form">${"#".repeat(form._0)} </span>`
  return ""
}

// The entries under a document: id, type and source. A pipe in a source is
// the box's caret, drawn as the caret is drawn in a block.
function sourceHtml(text) {
  const at = text.indexOf("|")
  if (at === -1) return escape(text)
  return `${escape(text.slice(0, at))}<span class="tree__caret"></span>${escape(text.slice(at + 1))}`
}

function listed(entries) {
  const rows = Object.entries(entries ?? {}).map(
    ([id, entry]) =>
      `<div class="tree__entry${entry.text.includes("|") ? " tree__entry--open" : ""}"><span class="tree__id">${escape(id)}</span><span class="tree__type">${escape(entry.type)}</span><span class="tree__source">${sourceHtml(entry.text)}</span></div>`,
  )
  return rows.length ? `<div class="tree__entries">${rows.join("")}</div>` : ""
}

function tree(doc, entries) {
  const blocks = doc.blocks
    .map(
      block =>
        `<li class="tree__block"><span class="tree__id">${escape(block.id)}</span><span class="tree__text${typeof block.form === "object" ? " tree__text--heading" : ""}">${lead(block)}${text(doc, block, entries) || '<span class="tree__empty">—</span>'}</span></li>`,
    )
    .join("")
  return `<ol class="tree">${blocks}</ol>${listed(entries)}`
}

// The argument of `input`, plain text with its caret, drawn the way a block
// draws it.
function line(source) {
  const {doc} = read(source, true)
  return doc.blocks.map(block => text(doc, block)).join("")
}

// The argument of `paste`, a document in the notation, drawn one block a
// line, its references drawn from the entries the section holds.
function lines(source, entries) {
  const {doc} = read(source)
  return doc.blocks.map(block => text(doc, block, entries)).join("\n")
}

const actLine = /^(\w+|->|<-)(?:\((.*)\))?$/s

function parsed(when) {
  return (Array.isArray(when) ? when : [when]).map(said => {
    const found = actLine.exec(said.trim())
    if (!found) throw new Error(`An act reads as a word with an argument: ${said}`)
    return {name: found[1], argument: found[2]}
  })
}

// One keycap per act: the key that runs it.
const keys = {
  backspace: "⌫",
  delete: "⌦",
  enter: "↵",
  input: "a",
  "->": "→",
  "<-": "←",
  bold: "B",
  italic: "I",
  code: "`",
  link: "K",
  moveUp: "⇧↑",
  moveDown: "⇧↓",
  paste: "⌘V",
  click: "⌖",
  heading: "H",
  paragraph: "P",
  item: "•",
  display: "⌥4",
  insert: "⌘M",
  edit: "⌖",
  escape: "⎋",
}

function sign(name) {
  return `<span class="op__key" aria-hidden="true">${keys[name] ?? "→"}</span>`
}

// The keycaps sit between the two panels. The acts themselves, name and
// argument, take a row under the panels, since an argument of `input` is a
// whole block in the notation and is drawn with its caret.
function acts(when) {
  return parsed(when)
    .map(({name}) => sign(name))
    .join("")
}

function arguments_(when, entries) {
  const rows = parsed(when).map(({name, argument}) => {
    const shown =
      argument === undefined
        ? ""
        : `<span class="op__argument-text">${name === "input" ? line(argument) : name === "paste" ? lines(argument, entries) : escape(argument)}</span>`
    return `<div class="op__argument"><kbd class="op__act-name">${escape(name)}</kbd>${shown}</div>`
  })
  return `<div class="op__arguments">${rows.join("")}</div>`
}

function card(example, feature) {
  for (const field of ["scenario", "before", "when", "after"]) {
    if (example[field] === undefined) {
      throw new Error(`An operation scenario says no ${field} (${feature})`)
    }
  }
  const before = read(example.before).doc
  const after = read(example.after).doc
  const entries = example.entries ?? {}
  const entriesAfter = example.entriesAfter ?? entries
  return [
    `<figure class="op" id="${slugify(example.scenario)}">`,
    `<figcaption class="op__head"><span class="op__title">${escape(example.scenario)}</span><span class="op__feature">${escape(feature)}</span></figcaption>`,
    '<div class="op__grid">',
    `<section class="op__side op__side--before"><p class="op__label">Before</p>${tree(before, entries)}</section>`,
    `<div class="op__act">${acts(example.when)}</div>`,
    `<section class="op__side op__side--after"><p class="op__label">After</p>${tree(after, entriesAfter)}</section>`,
    "</div>",
    arguments_(example.when, entries),
    "</figure>",
  ].join("")
}

const fixtures = new URL("../../packages/editor/src/design/operations/", import.meta.url)

export function operations(name) {
  const source = readFileSync(new URL(`${name.trim()}.yaml`, fixtures), "utf8")
  const fixture = parse(source)
  if (!fixture || typeof fixture.feature !== "string" || !Array.isArray(fixture.examples)) {
    throw new Error("An operations fixture holds a feature and its examples")
  }
  return fixture.examples.map(example => card(example, fixture.feature)).join("\n")
}
