import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, timeout: 120000,
  reporter: 'list', outputDir: '../../build/audio-browser-results',
  use: { baseURL: 'http://127.0.0.1:4800', headless: true,
    launchOptions: { args: ['--autoplay-policy=no-user-gesture-required', '--use-fake-device-for-media-stream', '--use-fake-ui-for-media-stream'], executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)), command: 'node ../../tools/audio/browser_runner.mjs', url: 'http://127.0.0.1:4800/tests/audio/fixture.html', timeout: 30000, reuseExistingServer: false },
})
