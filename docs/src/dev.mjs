import {fileURLToPath} from "node:url"
import {dev} from "@epure/minidoc"

const root = fileURLToPath(new URL("../", import.meta.url)).replace(/\/$/, "")
const workspace = fileURLToPath(new URL("../../", import.meta.url))

await dev({
  glob: "content/config.yaml",
  build: "src/build.mjs",
  root,
  watch: [`${workspace}docs/content/pages`, `${workspace}packages/editor/src/design`],
})
