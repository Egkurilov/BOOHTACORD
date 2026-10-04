import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 30000,
  reporter: 'list', outputDir: '../../../../.out/member-popover-browser-results',
  use: { baseURL: 'http://127.0.0.1:4802', headless: true,
    launchOptions: { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4802 --strictPort',
    url: 'http://127.0.0.1:4802/tests/member_popover/fixture.html', reuseExistingServer: false },
})
