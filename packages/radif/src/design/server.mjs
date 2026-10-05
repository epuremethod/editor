// The radif server the image scenarios run against: `radif dev` on a fresh
// directory and a free port, as `dev.mjs` starts it for the croquis. Its
// first line carries the founder's session.

import {spawn} from "node:child_process"
import {mkdtempSync, rmSync} from "node:fs"
import {createServer} from "node:net"
import {tmpdir} from "node:os"
import path from "node:path"
import {fileURLToPath} from "node:url"

const here = path.dirname(fileURLToPath(import.meta.url))
const radif = path.resolve(here, "../../node_modules/@radif/server/bin/radif.mjs")

const free = () =>
  new Promise((resolve, reject) => {
    const probe = createServer()
    probe.once("error", reject)
    probe.listen(0, "127.0.0.1", () => {
      const {port} = probe.address()
      probe.close(() => resolve(port))
    })
  })

export default async function setup(project) {
  const data = mkdtempSync(path.join(tmpdir(), "radif-images-"))
  const port = await free()
  const child = spawn("node", [radif, "dev", data, "--port", String(port)], {
    stdio: ["ignore", "pipe", "inherit"],
  })
  const session = await new Promise((resolve, reject) => {
    let said = ""
    child.stdout.on("data", chunk => {
      said += chunk
      const match = said.match(/^dev .* on (\d+) session=(\S+) code=(\S+)/m)
      if (match) resolve(match[2])
    })
    child.on("exit", code => reject(new Error(`radif dev left with ${code}: ${said}`)))
  })
  project.provide("radif", {base: `http://127.0.0.1:${port}`, session})
  return async () => {
    const left = new Promise(resolve => child.once("exit", resolve))
    child.kill("SIGTERM")
    await left
    rmSync(data, {recursive: true, force: true})
  }
}
