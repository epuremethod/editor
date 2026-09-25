import assert from "node:assert/strict"
import {existsSync, readFileSync} from "node:fs"
import test from "node:test"

const dist = new URL("../dist/", import.meta.url)
const page = name => readFileSync(new URL(name, dist), "utf8")

test("every page is built with the shell", () => {
  for (const name of ["index.html", "operations.html"]) {
    const html = page(name)
    assert.match(html, /<aside class="contents"/)
    assert.match(html, /<article class="prose"/)
  }
})

test("the operations page draws a card for the join fixture", () => {
  const html = page("operations.html")
  assert.match(html, /<figure class="op" id="/)
  assert.match(html, /<ol class="contents__sections">/)
  assert.match(html, /<span class="tree__caret"><\/span>/)
  assert.match(html, /Join/)
})

test("the editor page draws its schemas and flows", () => {
  const html = page("index.html")
  assert.match(html, /<figure class="schema">/)
  assert.match(html, /<span class="schema__class">Section<\/span>/)
  assert.match(html, /<span class="schema__embed">/)
  assert.match(html, /<figure class="flow">/)
  assert.match(html, /<ol class="contents__sections">/)
})

test("the demo page is built with the shell and loads the demo", () => {
  const html = page("demo.html")
  assert.match(html, /<aside class="contents"/)
  assert.match(html, /<article class="prose"/)
  assert.match(html, /id="demo-editor"/)
  assert.match(html, /<script type="module" src="\.\/demo\.js"><\/script>/)
  assert.ok(existsSync(new URL("demo.js", dist)))
})
