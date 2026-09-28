import path from "node:path"
import {fileURLToPath} from "node:url"
import {defineConfig} from "vite"

const here = path.dirname(fileURLToPath(import.meta.url))

// The page is the one exposed port. The proxy carries the wire and /listen
// to `lapa dev` under /_lapa/ and forwards Authorization untouched. Ben and
// Aisha open on two names for the one address, so the browser keeps two
// origins and two databases apart.
// `@lapa/tilia` is linked from sylva and brings its own tilia beside the one
// `@tilia/editor` holds; one copy serves the page, or a proxy made by one
// is not tracked by the other.
export default defineConfig({
  resolve: {dedupe: ["tilia", "@tilia/query", "react", "react-dom"]},
  server: {
    fs: {allow: [path.resolve(here, "../.."), path.resolve(here, "../../../sylva")]},
    host: "127.0.0.1",
    port: 8080,
    strictPort: true,
    allowedHosts: ["ben.lapa", "aisha.lapa"],
    proxy: {
      "/_lapa/": {
        target: "http://127.0.0.1:8081",
        rewrite: path => path.replace(/^\/_lapa/, ""),
        ws: true,
      },
    },
  },
})
