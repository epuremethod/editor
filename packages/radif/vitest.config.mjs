import {epureVitest} from "@epure/vitest"
import {defineConfig} from "vitest/config"

export default defineConfig({
  plugins: [epureVitest()],
  test: {
    include: ["src/design/**/*.feature"],
    globalSetup: ["src/design/server.mjs"],
    testTimeout: 20000,
  },
})
