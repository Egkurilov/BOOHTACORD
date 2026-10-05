import { fileURLToPath } from 'node:url'
import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, retries: 0, timeout: 60000,
  reporter: 'list', outputDir: '../../build/restricted-network-results',
  use: { baseURL: 'http://127.0.0.1:4900', headless: true, trace: 'off', screenshot: 'off', video: 'off',
    launchOptions: { args: ['--autoplay-policy=no-user-gesture-required'], executablePath: process.env.CHROMIUM_EXECUTABLE_PATH } },
  webServer: { cwd: fileURLToPath(new URL('../../', import.meta.url)), command: 'node ../../tools/network/restricted/browser.mjs',
    url: 'http://127.0.0.1:4900/tests/restricted_networks/fixture.html', timeout: 30000, reuseExistingServer: false },
})
