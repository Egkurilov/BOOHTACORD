import { chromium } from '@playwright/test'
import { pathToFileURL } from 'node:url'

const source = process.env.DESIGN_V2_REFERENCE_HTML
if (!source) throw new Error('DESIGN_V2_REFERENCE_HTML is required')
const browser = await chromium.launch({ headless: true })
try {
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } })
  await page.goto(pathToFileURL(source).href)
  await page.locator('.drawer-nav .section-head').nth(1).waitFor()
  await page.evaluate(() => document.fonts.ready)
  const selectors = ['.drawer-nav .section-head', '.drawer-nav .nav-channel', '.drawer-nav .voice-person']
  const measurements = Object.fromEntries(await Promise.all(selectors.map(async (selector) => [selector,
    await page.locator(selector).evaluateAll((elements) => elements.map((element) => {
      const box = element.getBoundingClientRect()
      return { text: element.textContent?.trim(), y: box.y, height: box.height }
    }))])))
  console.log(JSON.stringify(measurements, null, 2))
} finally { await browser.close() }
