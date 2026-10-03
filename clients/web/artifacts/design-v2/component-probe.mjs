import { chromium } from '@playwright/test'
import { readFileSync, writeFileSync } from 'node:fs'

const state = process.argv[2] ?? 'stream'
const width = Number(process.argv[3] ?? 1440)
const height = Number(process.argv[4] ?? 900)
const browser = await chromium.launch({ headless: true })
const page = await browser.newPage({ viewport: { width, height } })
await page.route('**/*', (route) => /\.(?:png|jpe?g|gif|webp|avif)(?:\?|$)/i.test(route.request().url()) ? route.abort() : route.continue())
await page.route('**/api/v1/media/**', (route) => route.fulfill({ status: 404, contentType: 'application/json', body: '{"error":"not found"}' }))
await page.goto(`${process.env.DESIGN_V2_URL ?? 'http://127.0.0.1:4173'}/artifacts/design-v2/component-harness.html?state=${state}`, { waitUntil: 'domcontentloaded' })
await page.locator('#app > *').waitFor({ state: 'attached' })
if (state === 'statistics') await page.locator('.stream-diagnostics').evaluate((details) => { details.open = true })
if (state === 'image') await page.locator('.attachment-card__open').evaluate((button) => button.click())
await page.waitForTimeout(100)
const selectors = ['.media-main', '.screen-viewer', '.screen-stage', '.stream-quality-row', '.stream-voice-return', '.screen-rail-section', '.screen-cards.stream-rail', '.stream-controls', '.stream-rail', '.stream-diagnostics-panel', '.screen-share-setup-dialog', '.screen-share-setup__header', '.screen-share-setup__body', '.screen-share-setup__footer', '.screen-share-quality__row', '.screen-share-quality__segments', '.voice-participant-volumes', '.voice-participant-volumes .participant', '.attachment-image-dialog', '.attachment-image-dialog__header', '.attachment-image-dialog__content']
const boxes = Object.fromEntries(await Promise.all(selectors.map(async (selector) => {
  const locator = page.locator(selector).first()
  const rect = await locator.count() ? await locator.boundingBox() : null
  return [selector, rect && Object.fromEntries(['x', 'y', 'width', 'height'].map((key) => [key, Math.round(rect[key] * 100) / 100]))]
})))
const visualProperties = ['display', 'position', 'boxSizing', 'width', 'height', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'gap', 'rowGap', 'columnGap', 'alignItems', 'justifyContent', 'flexDirection', 'fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing', 'color', 'backgroundColor', 'borderTopColor', 'borderTopWidth', 'borderRadius', 'boxShadow', 'opacity', 'overflowX', 'overflowY']
const styles = Object.fromEntries(await Promise.all(selectors.map(async (selector) => {
  const locator = page.locator(selector).first()
  return [selector, await locator.count() ? await locator.evaluate((element, properties) => Object.fromEntries(properties.map((property) => [property, getComputedStyle(element)[property]])), visualProperties) : null]
})))
const result = { state, viewport: { width, height }, boxes, styles, errors: await page.locator('[role=alert]').allTextContents() }
const id = state === 'quality' ? (width < 600 ? 'R30' : 'R20') : state === 'statistics' ? 'R19' : state === 'voice' ? 'R27' : state === 'image' ? 'R26' : width < 600 ? 'R05' : 'R04'
const inventory = JSON.parse(readFileSync(new URL('./reference-inventory.json', import.meta.url), 'utf8'))
const reference = inventory.items.find((entry) => entry.id === id)
const mapping = id === 'R20' || id === 'R30' ? { dialog: ['.dialog', '.screen-share-setup-dialog'] }
  : id === 'R26' ? { dialog: ['.image-dialog', '.attachment-image-dialog'] }
  : id === 'R19' ? { stage: ['.stage', '.screen-stage'], stageControls: ['.stage-controls', '.stream-quality-row'], streamRail: ['.stream-rail', '.screen-rail-section'], statistics: ['.stats-popover', '.stream-diagnostics-panel'] }
    : id === 'R27' ? { peopleStage: ['.people-stage', '.voice-participant-volumes'] }
      : { mediaMain: ['.media-main', '.media-main'], stage: ['.stage', '.screen-stage'], stageControls: ['.stage-controls', '.stream-quality-row'], streamRail: ['.stream-rail', '.screen-rail-section'] }
const roundBox = (value) => value && ['x', 'y', 'width', 'height'].map((key) => Math.round(value[key] * 100) / 100)
const actual = {}; const expected = {}; const diff = {}
for (const [key, [refSelector, actualSelector]] of Object.entries(mapping)) {
  expected[key] = reference.boxes[refSelector] ?? null
  actual[key] = roundBox(boxes[actualSelector])
  diff[key] = expected[key] && actual[key] ? actual[key].map((value, index) => Math.round((value - expected[key][index]) * 100) / 100) : null
}
const evidence = { name: id, width, height, file: `${id}.html`, state, reference: expected, actual, diff, source: 'Production Vue component rendered in Chromium; test fixture data only; raster requests blocked; no screenshots.' }
const evidencePath = new URL('./component-review.json', import.meta.url)
const prior = readFileSync(evidencePath, 'utf8')
const saved = JSON.parse(prior)
saved.screens = saved.screens.filter((screen) => screen.name !== id)
saved.screens.push(evidence)
writeFileSync(evidencePath, `${JSON.stringify(saved, null, 2)}\n`)
console.log(JSON.stringify(result, null, 2))
await browser.close()
