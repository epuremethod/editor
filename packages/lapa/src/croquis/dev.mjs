// The croquis's dev server: `lapa dev` on `.data`, the ReScript built, and
// vite in front. The croquis stores the root `Section`, so it defines no
// model. One command, and the first lines print where
// Ben opens and the code Aisha joins with.

import {execFileSync, spawn} from "node:child_process"
import path from "node:path"
import {fileURLToPath} from "node:url"

const here = path.dirname(fileURLToPath(import.meta.url))
const pkg = path.resolve(here, "../..")
const data = path.join(pkg, ".data")
const lapa = path.join(pkg, "node_modules/@lapa/server/bin/lapa.mjs")
const port = 8081

// `lapa dev` in the foreground; the first line carries the session and the
// admission code.
function serve() {
  const args = [lapa, "dev", data, "--port", String(port)]
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

const served = serve()
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
