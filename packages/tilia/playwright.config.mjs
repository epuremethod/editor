import {defineConfig} from "@playwright/test"

// The browser suite runs the model's fixtures against the dev page. Chrome
// is the installed one; `channel` keeps Playwright from downloading its own.
export default defineConfig({
  testDir: "src/design",
  testMatch: "**/*.spec.mjs",
  fullyParallel: false,
  workers: 1,
  reporter: [["list"]],
  use: {channel: "chrome", headless: true, baseURL: "http://localhost:8090"},
  // The built bundle, served static: the dev server re-optimizes its
  // dependencies mid-suite and a page load then hangs.
  webServer: {
    command: "pnpm vite build && pnpm vite preview --port 8090 --strictPort",
    url: "http://localhost:8090",
    reuseExistingServer: false,
    timeout: 60000,
  },
})
