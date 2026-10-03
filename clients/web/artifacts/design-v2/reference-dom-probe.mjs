import { chromium } from '@playwright/test'
import { pathToFileURL } from 'node:url'

const sourceRoot = 'C:/Users/egkur/Downloads/BOOHTACORD_DESIGN_V2_LIVE_HTML_SOURCE_2026-10-03/BOOHTACORD_DESIGN_V2_HTML/screens'
const id = process.argv[2] ?? 'R22'
const browser = await chromium.launch({ headless: true })
const viewport = ['R02', 'R05', 'R07', 'R09', 'R11', 'R14', 'R17', 'R19', 'R22', 'R30'].includes(id) ? { width: 390, height: 844 } : { width: 1440, height: 900 }
const page = await browser.newPage({ viewport })
await page.route('**/*', (route) => route.request().resourceType() === 'image' ? route.abort() : route.continue())
await page.goto(pathToFileURL(`${sourceRoot}/${id}.html`).href, { waitUntil: 'networkidle' })
const result = await page.evaluate(() => {
  const selectors = ['.shell', '.workspace', '.header', '.settings-body', '.settings-inner', '.admin-mobile', '.admin-card', '.admin-card > *', '.panel', '.permission-table', '.permission-table tbody tr', '.notice', '.savebar', '.between', '.admin-table', '.admin-table tr', '.admin-table tbody tr', '.mobile-only', '.dialog', '.image-dialog', '.reply-strip', '.mention-popover', '.auth-card', '.member-popover', '.stats-popover', '.searchpane', '.updatebar', '.people-stage']
  return Object.fromEntries(selectors.map((selector) => [selector, [...document.querySelectorAll(selector)].slice(0, selector === '.admin-card' ? 6 : selector === '.admin-card > *' ? 12 : 1).map((element) => {
    const rect = element.getBoundingClientRect()
    const style = getComputedStyle(element)
    return { tag: element.tagName, class: element.className, text: element.textContent.trim().replace(/\s+/g, ' ').slice(0, selector === '.auth-card' || selector === '.member-popover' ? 400 : 100), x: rect.x, y: rect.y, width: rect.width, height: rect.height, display: style.display, color: style.color, background: style.backgroundColor, padding: style.padding, gap: style.gap }
  })]))
})
console.log(JSON.stringify({ id, viewport: page.viewportSize(), result }, null, 2))
await browser.close()
