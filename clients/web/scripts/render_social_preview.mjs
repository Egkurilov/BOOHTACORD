import { mkdir } from 'node:fs/promises'
import { resolve } from 'node:path'
import { pathToFileURL } from 'node:url'
import { chromium } from '@playwright/test'

const root = resolve(import.meta.dirname, '..')
const output = resolve(root, 'public/social/boohtacord-og-1200x630.png')
const browser = await chromium.launch({ headless: true })
try {
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 }, deviceScaleFactor: 1 })
  await page.goto(pathToFileURL(resolve(root, 'social-preview/boohtacord-og.html')).href)
  await page.evaluate(() => document.fonts.ready)
  await page.locator('.brand img').evaluate((image) => image.decode())
  await mkdir(resolve(root, 'public/social'), { recursive: true })
  await page.screenshot({ path: output, fullPage: true })
} finally {
  await browser.close()
}
