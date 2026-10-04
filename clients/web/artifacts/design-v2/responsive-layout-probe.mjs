import assert from 'node:assert/strict'
import { writeFileSync } from 'node:fs'
import { chromium } from '@playwright/test'
import { chatMembers, chatMessages, chatProfile, chatTopology } from './chat-reference-fixture.mjs'
import { connectReferenceVoiceStore, installReferenceTransports } from './reference-live-state.mjs'

const sizes = [[320, 640], [390, 844], [430, 932], [768, 1024], [1023, 768], [1024, 768], [1279, 800], [1280, 800], [1440, 900], [1920, 1080], [844, 390]]
const browser = await chromium.launch({ headless: true })
const page = await browser.newPage({ viewport: { width: 390, height: 844 } })
const errors = []
page.on('pageerror', (error) => errors.push(error.message))
await installReferenceTransports(page)
await page.route('**/api/v1/**', async (route) => {
  const path = new URL(route.request().url()).pathname
  let body = {}
  if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: chatProfile.role }
  else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: chatProfile.role, permissions_revision: 1, permissions: { 'category.create': true, 'category.delete': true, 'channel.text.create': true, 'channel.text.delete': true, 'channel.voice.create': true, 'channel.voice.delete': true } }
  else if (path.endsWith('/channels')) body = chatTopology
  else if (path.endsWith('/me')) body = chatProfile
  else if (path.endsWith('/members')) body = { members: chatMembers }
  else if (path.includes('/members/')) body = chatMembers.find((member) => path.endsWith(`/${member.user_id}`)) ?? {}
  else if (path.endsWith('/direct-messages')) body = { direct_messages: [] }
  else if (path.includes('/messages')) body = { messages: chatMessages }
  else if (path.includes('/read-cursor')) body = { message_id: null }
  else if (path.includes('/maintenance')) body = { active: false }
  else if (path.includes('/client-updates')) body = { state: 'unconfigured', target: null }
  await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
})

function checkLayout(voice) {
  const rect = (element) => {
    if (!element) return null
    const box = element.getBoundingClientRect()
    return { x: Math.round(box.x), y: Math.round(box.y), width: Math.round(box.width), height: Math.round(box.height), right: Math.round(box.right), bottom: Math.round(box.bottom) }
  }
  const visible = (element) => element && getComputedStyle(element).display !== 'none' && element.getClientRects().length > 0
  const compose = document.querySelector('#message-body')
  const wrap = compose?.closest('.composer-wrap')
  const dock = voice ? [...document.querySelectorAll('.voice-dock')].find(visible) : null
  const leave = dock?.querySelector('[aria-label="Выйти из голосового канала"]')
  return {
    width: innerWidth, height: innerHeight, voice,
    documentWidth: document.documentElement.scrollWidth,
    shellWidth: document.querySelector('.gc-shell')?.scrollWidth,
    composer: rect(wrap), textarea: rect(compose), dock: rect(dock), leave: rect(leave),
    actionTargets: [...(wrap?.querySelectorAll('button') ?? [])].filter(visible).map((button) => ({ label: button.getAttribute('aria-label'), ...rect(button) })),
  }
}

const results = []
try {
  await page.goto(process.env.DESIGN_V2_URL ?? 'http://127.0.0.1:4175/', { waitUntil: 'domcontentloaded' })
  await page.locator('#message-body').waitFor({ state: 'visible' })
  for (const voice of [false, true]) {
    if (voice) await connectReferenceVoiceStore(page)
    for (const [width, height] of sizes) {
      await page.setViewportSize({ width, height })
      await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))))
      results.push(await page.evaluate(checkLayout, voice))
      if (voice && process.env.DESIGN_V2_RESPONSIVE_SCREENSHOT_DIR && ((width === 320 && height === 640) || (width === 844 && height === 390))) {
        await page.screenshot({ path: `${process.env.DESIGN_V2_RESPONSIVE_SCREENSHOT_DIR}/${width}x${height}-voice-actual.png` })
      }
    }
  }
  await page.setViewportSize({ width: 390, height: 844 })
  await page.getByRole('button', { name: 'Открыть навигацию' }).click()
  const drawerTargets = await page.locator('.sidebar.is-open').evaluate((drawer) => [
    ...drawer.querySelectorAll('.mobile-nav-close, .channel-navigation-actions button, .channel-category-actions button, .mobile-voice-dock .voice-actions button'),
  ].filter((button) => getComputedStyle(button).display !== 'none').map((button) => ({
    label: button.getAttribute('aria-label') ?? button.textContent.trim(),
    width: Math.round(button.getBoundingClientRect().width),
    height: Math.round(button.getBoundingClientRect().height),
  })))
  await page.getByRole('button', { name: 'Закрыть навигацию', exact: true }).click()
  await page.locator('.nav-drawer').waitFor({ state: 'hidden' })
  if (process.env.DESIGN_V2_RESPONSIVE_REPORT) writeFileSync(process.env.DESIGN_V2_RESPONSIVE_REPORT, JSON.stringify({ results, drawerTargets, pageErrors: errors }, null, 2))
  assert.deepEqual(errors, [])
  assert.ok(drawerTargets.length > 0 && drawerTargets.every((target) => target.width >= 44 && target.height >= 44), 'drawer controls expose 44px touch targets')
  const failures = results.filter((item) => item.documentWidth > item.width || item.composer?.right > item.width + 1 || item.composer?.bottom > item.height + 1 || (item.width <= 1023 && item.actionTargets.some((target) => target.width < 44 || target.height < 44)) || (item.voice && (!item.leave || item.leave.right > item.width + 1 || item.leave.bottom > item.height + 1)))
  process.stdout.write(JSON.stringify({ cases: results.length, failures }, null, 2))
  if (failures.length) process.exitCode = 1
} finally {
  await browser.close()
}
