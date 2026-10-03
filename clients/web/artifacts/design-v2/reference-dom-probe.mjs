import { chromium } from '@playwright/test'
import { readFileSync } from 'node:fs'
import { pathToFileURL } from 'node:url'

const sourceRoot = 'C:/Users/egkur/Downloads/BOOHTACORD_DESIGN_V2_LIVE_HTML_SOURCE_2026-10-03/BOOHTACORD_DESIGN_V2_HTML/screens'
const id = process.argv[2] ?? 'R22'
const browser = await chromium.launch({ headless: true })
const viewport = JSON.parse(readFileSync(new URL('./reference-inventory.json', import.meta.url), 'utf8')).items.find((screen) => screen.id === id)?.viewport ?? { width: 1440, height: 900 }
const page = await browser.newPage({ viewport })
await page.route('**/*', (route) => route.request().resourceType() === 'image' ? route.abort() : route.continue())
await page.goto(pathToFileURL(`${sourceRoot}/${id}.html`).href, { waitUntil: 'networkidle' })
const result = await page.evaluate(() => {
  const selectors = ['.shell', '.sidebar', '.guild', '.nav-body', '.voice-dock', '.account', '.workspace', '.header', '.conversation', '.history', '.composer-wrap', '.composer', '.members', '.stage', '.stage-controls', '.stream-rail', '.settings-body', '.panel', '.dialog', '.auth-screen', '.auth-card', '.searchpane', '.stats-popover', '.role-selector', '.permission-table', '.member-popover', '.drawer-nav', '.drawer-scrim', '.nav-channel.selected', '.updatebar', '.media-main', '.stage-info', '.people-stage', '.savebar', '.admin-mobile', '.admin-card', '.admin-card > *', '.notice', '.between', '.devicegrid', '.mobile-only', '.image-dialog', '.reply-strip', '.mention-popover', '.contextmenu', '.menu-item', '.search-results', '.result', '.profile-panel', '.admin-table', '.admin-table thead', '.admin-table tbody tr']
  return Object.fromEntries(selectors.map((selector) => [selector, [...document.querySelectorAll(selector)].slice(0, selector === '.admin-card' ? 6 : selector === '.admin-card > *' ? 12 : 1).map((element) => {
    const rect = element.getBoundingClientRect()
    const style = getComputedStyle(element)
    const properties = ['display', 'position', 'boxSizing', 'width', 'height', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'gap', 'rowGap', 'columnGap', 'alignItems', 'justifyContent', 'flexDirection', 'fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing', 'color', 'backgroundColor', 'borderTopColor', 'borderTopWidth', 'borderRadius', 'boxShadow', 'opacity', 'overflowX', 'overflowY']
    return { tag: element.tagName, class: element.className, x: rect.x, y: rect.y, width: rect.width, height: rect.height, style: Object.fromEntries(properties.map((property) => [property, style[property]])) }
  })]))
})
console.log(JSON.stringify({ id, viewport: page.viewportSize(), result }, null, 2))
await browser.close()
