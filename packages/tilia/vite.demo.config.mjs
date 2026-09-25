import {fileURLToPath} from "node:url"
import {defineConfig} from "vite"

// The demo on the docs site: one ES module, React and tilia inside, no hash,
// so the site copies it by a fixed name.
export default defineConfig({
  publicDir: false,
  build: {
    outDir: "dist-demo",
    emptyOutDir: true,
    rollupOptions: {
      input: fileURLToPath(new URL("src/view/app/Demo.res.mjs", import.meta.url)),
      output: {format: "es", entryFileNames: "demo.js"},
    },
  },
})
