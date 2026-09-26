// The model's operation fixtures, run in the browser. Each scenario loads
// its `before` into the dev page, turns each act into keys, and reads the
// document back in the notation. A scenario an act cannot drive from a
// keyboard is skipped and says so.

import {readdirSync, readFileSync} from "node:fs"
import {expect, test} from "@playwright/test"
import {parse} from "yaml"
import {read, write} from "@epure/editor/src/domain/feature/Notation.res.mjs"

const dir = new URL("../../../editor/src/design/operations/", import.meta.url)
const actLine = /^(\w+|->|<-)(?:\((.*)\))?$/s

const keys = {
  backspace: "Backspace",
  delete: "Delete",
  enter: "Enter",
  "->": "ArrowRight",
  "<-": "ArrowLeft",
  bold: "ControlOrMeta+b",
  italic: "ControlOrMeta+i",
  code: "ControlOrMeta+e",
  moveUp: "ControlOrMeta+Shift+ArrowUp",
  moveDown: "ControlOrMeta+Shift+ArrowDown",
  paragraph: "ControlOrMeta+Alt+Digit0",
  item: "ControlOrMeta+Shift+Digit8",
  display: "ControlOrMeta+Alt+Digit4",
  escape: "Escape",
}

// The entries of a scenario, with the box's caret: a pipe in an entry's
// text is the caret, as the model's harness reads it.
const entriesOf = given => {
  const entries = {}
  let editing = null
  for (const [id, entry] of Object.entries(given ?? {})) {
    const at = entry.text.indexOf("|")
    if (at === -1) entries[id] = entry
    else {
      editing = {entry: id, offset: at}
      entries[id] = {...entry, text: entry.text.replace("|", "")}
    }
  }
  return {entries, editing}
}

// `heading(n)` is Cmd+Alt and the digit of its level.
const keyFor = ({name, argument}) => (name === "heading" ? `ControlOrMeta+Alt+Digit${argument}` : keys[name])

const acts = when => (Array.isArray(when) ? when : [when]).map(said => {
  const found = actLine.exec(String(said).trim())
  return {name: found[1], argument: found[2]}
})

// Sets the DOM selection inside one block from plain-text offsets. An atom
// counts as its reference, an offset at its edge is the position beside
// it, and a zero-width space counts as nothing.
const select = ({id, from, to}) => {
  const block = document.querySelector(`#block-${id}`)
  const zwsp = "\u200b"
  const units = []
  const walk = node => {
    if (node.nodeType === 3) units.push({node, length: node.nodeValue.replaceAll(zwsp, "").length})
    else if (node.dataset && node.dataset.atom !== undefined) units.push({node, length: node.dataset.atom.length, atom: true})
    else [...node.childNodes].forEach(walk)
  }
  walk(block)
  const rawIndex = (node, count) => {
    let index = 0
    let seen = 0
    while (seen < count && index < node.nodeValue.length) {
      if (node.nodeValue[index] !== zwsp) seen++
      index++
    }
    return index
  }
  const beside = (atom, after) => {
    const sibling = after ? atom.nextSibling : atom.previousSibling
    if (sibling && sibling.nodeType === 3) return [sibling, after ? 0 : sibling.nodeValue.length]
    return [atom.parentNode, [...atom.parentNode.childNodes].indexOf(atom) + (after ? 1 : 0)]
  }
  const at = offset => {
    let before = 0
    for (const unit of units) {
      if (unit.atom) {
        if (offset <= before) return beside(unit.node, false)
        if (offset <= before + unit.length) return beside(unit.node, true)
      } else if (before + unit.length >= offset) return [unit.node, rawIndex(unit.node, offset - before)]
      before += unit.length
    }
    const last = units.at(-1)
    if (!last) return [block, 0]
    return last.atom ? beside(last.node, true) : [last.node, last.node.nodeValue.length]
  }
  const [a, ao] = at(from)
  const [f, fo] = at(to)
  document.getSelection().setBaseAndExtent(a, ao, f, fo)
}

const settle = page => page.evaluate(() => new Promise(done => setTimeout(done, 25)))

// The document the page holds now, read through the hook.
const current = async page => read(await page.evaluate(() => window.editor.notation(true))).doc

const focused = doc => {
  const {anchor, focus} = doc.selection
  const index = id => doc.blocks.findIndex(block => block.id === id)
  const [start, stop] = [anchor, focus].sort((a, b) => index(a.block) - index(b.block) || a.offset - b.offset)
  return {id: focus.block, lo: start.block === focus.block ? start.offset : 0, hi: stop.block === focus.block ? stop.offset : focus.offset}
}

// `input(...)` as keys: the span that changed, bounded by the old
// selection the way the model bounds it, selected and typed over.
async function typeInput(page, argument) {
  const doc = await current(page)
  const {id, lo, hi} = focused(doc)
  const old = doc.blocks.find(block => block.id === id).content.text
  const next = read(argument, true).doc.blocks[0].content.text
  let prefix = 0
  const limit = Math.min(lo, old.length, next.length)
  while (prefix < limit && old[prefix] === next[prefix]) prefix++
  let suffix = 0
  const most = Math.min(old.length - hi, Math.min(old.length, next.length) - prefix)
  while (suffix < most && old[old.length - 1 - suffix] === next[next.length - 1 - suffix]) suffix++
  const from = prefix
  const to = old.length - suffix
  const inserted = next.slice(prefix, next.length - suffix)
  await page.evaluate(select, {id, from, to})
  await settle(page)
  if (inserted === "") await page.keyboard.press("Backspace")
  else await page.keyboard.type(inserted)
}

async function click(page, argument) {
  const doc = await current(page)
  const id = doc.selection ? doc.selection.focus.block : doc.blocks[0].id
  const offset = read(argument, true).doc.selection.focus.offset
  await page.evaluate(select, {id, from: offset, to: offset})
}

// The two parts of an argument, parted by the first comma and space.
const twoParts = argument => {
  const at = argument.indexOf(", ")
  return [argument.slice(0, at), argument.slice(at + 2)]
}

// `edit(id, text)` as the box's source replaced. When the box is open the
// source is typed over in place; otherwise a click on the atom opens it,
// and Escape closes it after.
async function editEntry(page, argument, open) {
  const [id, text] = twoParts(argument)
  if (!open) await page.click(`[data-ref="${id}"]`)
  await page.waitForSelector(".box__source")
  await page.keyboard.press("ControlOrMeta+a")
  await page.keyboard.type(text)
  if (!open) await page.keyboard.press("Escape")
}

// `insert(math, text)` as Cmd+M, the source typed into the box, and Escape.
async function insertEntry(page, argument) {
  const [, text] = twoParts(argument)
  await page.keyboard.press("ControlOrMeta+m")
  await page.waitForSelector(".box__source")
  await page.keyboard.type(text)
  await page.keyboard.press("Escape")
}

const drivable = when =>
  acts(when).every(
    act =>
      keyFor(act) ||
      act.name === "input" ||
      act.name === "click" ||
      act.name === "edit" ||
      (act.name === "insert" && act.argument.startsWith("math, ")),
  )

for (const file of readdirSync(dir).filter(name => name.endsWith(".yaml"))) {
  const fixture = parse(readFileSync(new URL(file, dir), "utf8"))
  test.describe(fixture.feature, () => {
    for (const example of fixture.examples) {
      const run = drivable(example.when) ? test : test.skip
      run(example.scenario, async ({page}) => {
        await page.goto("/", {waitUntil: "domcontentloaded"})
        await page.waitForSelector("#block-a")
        await page.locator(".editor").focus()
        const {entries, editing} = entriesOf(example.entries)
        await page.evaluate(
          ([source, entries, editing]) => window.editor.load(source, entries, editing),
          [example.before, entries, editing],
        )
        await settle(page)
        for (const act of acts(example.when)) {
          const {name, argument} = act
          if (name === "input") await typeInput(page, argument)
          else if (name === "click") await click(page, argument)
          else if (name === "edit") await editEntry(page, argument, editing !== null)
          else if (name === "insert") await insertEntry(page, argument)
          else await page.keyboard.press(keyFor(act))
          await settle(page)
        }
        const after = read(example.after)
        const expected = write(after.doc, after.labeled)
        const got = await page.evaluate(labels => window.editor.notation(labels), after.labeled)
        expect(got).toBe(expected)
        if (example.entriesAfter) {
          const wanted = entriesOf(example.entriesAfter)
          expect(await page.evaluate(() => window.editor.entries())).toEqual(wanted.entries)
          expect((await page.evaluate(() => window.editor.editing())) ?? null).toEqual(wanted.editing)
        }
      })
    }
  })
}
