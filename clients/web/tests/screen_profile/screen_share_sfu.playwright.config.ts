import { defineConfig } from '@playwright/test'
import base from './playwright.config'

export default defineConfig({ ...base, testMatch: 'screen_share_sfu.browser.spec.ts', testIgnore: [] })
