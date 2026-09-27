import {defineConfig} from "vite"

// The page is the one exposed port. The proxy carries the wire and /listen
// to `lapa dev` under /_lapa/ and forwards Authorization untouched. Ben and
// Aisha open on two names for the one address, so the browser keeps two
// origins and two databases apart.
export default defineConfig({
  server: {
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
