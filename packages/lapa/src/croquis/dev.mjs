// The croquis's dev server: `lapa dev` on `.data`, the Course app defined
// on a fresh deployment, the ReScript built once the generated file is
// there, and vite in front. One command, and the first lines print where
// Ben opens and the code Aisha joins with.

import {execFileSync, spawn} from "node:child_process"
import {existsSync, readFileSync, writeFileSync} from "node:fs"
import path from "node:path"
import {fileURLToPath} from "node:url"

const here = path.dirname(fileURLToPath(import.meta.url))
const pkg = path.resolve(here, "../..")
const data = path.join(pkg, ".data")
const lapa = path.join(pkg, "node_modules/@lapa/server/bin/lapa.mjs")
const port = 8081
const base = `http://127.0.0.1:${port}`

const fresh = !existsSync(path.join(data, "dev.json"))

// `lapa dev` in the foreground; the first line carries the session and the
// admission code. `--types` writes the generated file after every batch, and
// it writes `Lapa.direct` on a many text field where `Lapa.many` is due, so
// it is asked once, on a fresh deployment, and the file is patched by hand.
function serve(types) {
  const args = [lapa, "dev", data, "--port", String(port), ...(types ? ["--types", here] : [])]
  const child = spawn("node", args, {stdio: ["ignore", "pipe", "inherit"]})
  const line = new Promise((resolve, reject) => {
    let said = ""
    child.stdout.on("data", chunk => {
      said += chunk
      const match = said.match(/^dev .* on (\d+) session=(\S+) code=(\S+)/m)
      if (match) resolve({session: match[2], code: match[3]})
    })
    child.on("exit", code => reject(new Error(`lapa dev left with ${code}: ${said}`)))
  })
  return {child, line}
}

async function tool(session, name, args) {
  const response = await fetch(`${base}/mcp`, {
    method: "POST",
    headers: {Authorization: session},
    body: JSON.stringify({jsonrpc: "2.0", id: 1, method: "tools/call", params: {name, arguments: args}}),
  })
  const {result} = JSON.parse(await response.text())
  if (result.isError) throw new Error(`${name}: ${result.content[0].text}`)
  return JSON.parse(result.content[0].text)
}

// The model the croquis stands on: one app, one class, two lists of text.
async function define(session) {
  await tool(session, "app", {
    title: "Course",
    description: "A course on topology, written in sections.",
  })
  await tool(session, "define", {
    classes: [
      {
        title: "Section",
        description: "One section of a chapter: the unit a person shares and edits.",
        fields: [
          {title: "blocks", kind: "text", many: true, description: "The blocks in order, each its markdown."},
          {title: "atoms", kind: "text", many: true, description: "The atoms the blocks refer to, the type on the first line."},
        ],
      },
    ],
  })
}

const wait = ms => new Promise(resolve => setTimeout(resolve, ms))

const generated = path.join(here, "Course.res")
const stopped = child => new Promise(resolve => {
  child.on("exit", resolve)
  child.kill("SIGTERM")
})

if (fresh) {
  const typing = serve(true)
  await define((await typing.line).session)
  while (!existsSync(generated)) await wait(100)
  await stopped(typing.child)
  writeFileSync(
    generated,
    readFileSync(generated, "utf8").replace(/Lapa\.direct(, \[> #\w+\]> = Lapa\.entries\()/g, "Lapa.many$1"),
  )
}

const served = serve(false)
const {session, code} = await served.line

execFileSync("pnpm", ["rescript"], {cwd: pkg, stdio: "inherit"})
const vite = spawn("pnpm", ["vite"], {cwd: pkg, stdio: ["ignore", "inherit", "inherit"]})

const leaving = () => {
  vite.kill("SIGTERM")
  served.child.kill("SIGTERM")
  process.exit(0)
}
process.on("SIGINT", leaving)
process.on("SIGTERM", leaving)

console.log(`\nBen:   http://ben.lapa:8080/?lapa-session=${session}`)
console.log(`Aisha: http://aisha.lapa:8080/?lapa-code=${code}\n`)
