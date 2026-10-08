import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 30000,
  reporter: 'list', outputDir: '../../../../.out/search-dates-browser-results',
  projects: [
    { name: 'UTC', use: { timezoneId: 'UTC' } },
    { name: 'NewYork', use: { timezoneId: 'America/New_York' } },
  ],
  use: { baseURL: 'http://127.0.0.1:4818', headless: true, trace: 'off', screenshot: 'off', video: 'off', launchOptions: { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)), command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4818 --strictPort', url: 'http://127.0.0.1:4818/tests/search_dates/fixture.html', reuseExistingServer: false },
})
