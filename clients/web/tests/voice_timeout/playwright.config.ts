import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 30000,
  reporter: 'list', outputDir: '../../../../.out/voice-timeout-browser-results',
  projects: [390, 1440].map(width => ({ name: `width-${width}`, use: { viewport: { width, height: 900 } } })),
  use: { baseURL: 'http://127.0.0.1:4917', headless: true, trace: 'off', screenshot: 'off', video: 'off',
    launchOptions: { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)),
    command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4917 --strictPort',
    url: 'http://127.0.0.1:4917/tests/voice_timeout/fixture.html', reuseExistingServer: false },
})
