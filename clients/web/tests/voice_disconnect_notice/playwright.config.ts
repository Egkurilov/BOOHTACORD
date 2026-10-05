import { defineConfig } from '@playwright/test'
export default defineConfig({
 testDir: '.', testMatch: '*.browser.spec.ts', workers: 1, reporter: 'list',
 use: { baseURL: 'http://127.0.0.1:4813', headless: true },
 webServer: { cwd: process.cwd(), command: 'node node_modules/vite/bin/vite.js --host 127.0.0.1 --port 4813 --strictPort', url: 'http://127.0.0.1:4813/tests/voice_disconnect_notice/fixture.html' },
})
