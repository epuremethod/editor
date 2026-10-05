import path from "node:path"
import {fileURLToPath} from "node:url"
import {defineConfig} from "vite"

const here = path.dirname(fileURLToPath(import.meta.url))

// The page is the one exposed port. The proxy carries the wire and /listen
// to `radif dev` under /_radif/ and forwards Authorization untouched. Ben and
// Aisha open on two names for the one address, so the browser keeps two
// origins and two databases apart. The names are under `localhost`, which
// Chrome counts as a secure context: radif signs each object read with
// `crypto.subtle`, which a plain http origin does not have.
// `@radif/tilia` is linked from radif and brings its own tilia beside the one
// `@tilia/editor` holds; one copy serves the page, or a proxy made by one
// is not tracked by the other.
export default defineConfig({
  resolve: {dedupe: ["tilia", "@tilia/query", "react", "react-dom"]},
  server: {
    fs: {allow: [path.resolve(here, "../.."), path.resolve(here, "../../../radif")]},
    host: "127.0.0.1",
    port: 8080,
    strictPort: true,
    proxy: {
      "/_radif/": {
        target: "http://127.0.0.1:8081",
        rewrite: path => path.replace(/^\/_radif/, ""),
        ws: true,
      },
    },
  },
})
