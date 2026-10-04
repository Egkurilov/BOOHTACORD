import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
 testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 30000,
 reporter: 'list', outputDir: '../../build/voice-shortcut-results',
 use: { baseURL: 'http://127.0.0.1:4806', headless: true, trace: 'off', screenshot: 'off', video: 'off', launchOptions: { executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } },
 webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)), command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4806 --strictPort', url: 'http://127.0.0.1:4806/tests/voice_shortcuts/fixture.html', reuseExistingServer: false },
})
