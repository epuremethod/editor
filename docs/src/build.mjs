import {fileURLToPath} from "node:url"
import {nodeFs, run} from "@epure/minidoc"
import {docsMd, docsToc} from "./markdown.mjs"
import {operations} from "./operations.mjs"

const root = new URL("../", import.meta.url)

export async function build() {
  await run({
    fs: nodeFs(fileURLToPath(root).replace(/\/$/, "")),
    glob: "content/config.yaml",
    transform: {docsMd, docsToc, operations},
  })
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  await build()
}
