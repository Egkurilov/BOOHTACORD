import { chromium } from '@playwright/test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { chatMembers, chatMessages, chatProfile, chatTopology } from './chat-reference-fixture.mjs'

const out = process.env.DESIGN_V2_ARTIFACT_DIR
if (!out) throw new Error('DESIGN_V2_ARTIFACT_DIR is required')
mkdirSync(out, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4178'], { stdio: 'ignore' })
process.on('exit', () => server.kill())
server.unref()
const url = 'http://127.0.0.1:4178/'
for (let attempt = 0; attempt < 50; attempt += 1) {
  try { if ((await fetch(url)).ok) break } catch { /* Vite is starting. */ }
  await new Promise((resolve) => setTimeout(resolve, 100))
}
const browser = await chromium.launch({ headless: true })
const permissions = { 'channel.text.create': true, 'channel.text.delete': true, 'channel.voice.create': true,
  'channel.voice.delete': true, 'category.create': true, 'category.delete': true }
const results = []
for (const [kind, width, height] of [['channel', 1440, 900], ['dm', 1440, 900], ['channel', 320, 640], ['dm', 320, 640]]) {
  const page = await browser.newPage({ viewport: { width, height } })
  const errors = []
  let sends = 0
  page.on('pageerror', (error) => errors.push(error.message))
  await page.route('**/api/v1/**', async (route) => {
    const path = new URL(route.request().url()).pathname
    let body = {}
    if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR' }
    else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR', permissions_revision: 1, permissions }
    else if (path.endsWith('/channels')) body = chatTopology
    else if (path.endsWith('/me')) body = chatProfile
    else if (path.endsWith('/members')) body = { members: chatMembers }
    else if (path.endsWith('/direct-messages')) body = { direct_messages: [{ id: 'dm-review', other_participant_id: 'daria-2', other_participant_display_name: 'Daria', created_at: '2026-10-03T10:00:00Z', unread_count: 0, mention_count: 0 }] }
    else if (path.includes('/messages')) { if (route.request().method() === 'POST') sends += 1; body = { messages: chatMessages } }
    else if (path.includes('/read-cursor')) body = { message_id: null }
    else if (path.includes('/maintenance')) body = { active: false }
    else if (path.includes('/client-updates')) body = { state: 'unconfigured', target: null }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  })
  await page.goto(url, { waitUntil: 'domcontentloaded' })
  await page.locator('.gc-shell').waitFor()
  if (kind === 'dm') {
    if (width < 1024) await page.getByRole('button', { name: 'Открыть навигацию' }).click()
    await page.getByRole('button', { name: 'Личные', exact: true }).click()
    await page.locator('.direct-message-navigation .channel-button').filter({ hasText: 'Daria' }).click()
  }
  const textarea = page.locator(kind === 'dm' ? '#direct-message-body' : '#message-body')
  await textarea.fill('Привет мир')
  await textarea.evaluate((element) => element.setSelectionRange(7, 10))
  async function openPicker() {
    if (width < 1024) { await page.getByRole('button', { name: 'Действия редактора' }).click(); await page.getByRole('group', { name: 'Действия редактора' }).getByRole('button', { name: 'Emoji' }).click() }
    else await page.getByRole('button', { name: 'Добавить emoji' }).click()
    await page.getByRole('dialog', { name: 'Выбор emoji' }).waitFor()
  }
  await openPicker()
  const picker = page.getByRole('dialog', { name: 'Выбор emoji' })
  await picker.getByRole('button', { name: 'Все emoji' }).click()
  await picker.getByRole('searchbox', { name: 'Поиск emoji' }).fill('палец')
  await picker.getByRole('button', { name: 'большой палец средний тон' }).waitFor()
  await picker.getByRole('searchbox', { name: 'Поиск emoji' }).fill('avocado')
  await picker.getByRole('button', { name: 'avocado' }).waitFor()
  await picker.getByRole('searchbox', { name: 'Поиск emoji' }).fill('палец')
  const bounds = await picker.boundingBox()
  assert.ok(bounds && bounds.x >= 0 && bounds.x + bounds.width <= width && bounds.y >= 0, `picker bounds at ${width}`)
  await page.screenshot({ path: `${out}/emoji-${kind}-${width}-actual.png`, fullPage: true })
  await picker.getByRole('button', { name: 'большой палец средний тон' }).click()
  assert.equal(await textarea.inputValue(), 'Привет 👍🏽')
  assert.equal(await textarea.evaluate((element) => element.selectionStart), 11)
  assert.equal(await textarea.evaluate((element) => document.activeElement === element), true)
  assert.equal(sends, 0)
  await openPicker()
  await picker.getByRole('button', { name: 'Все emoji' }).click()
  assert.match(await picker.locator('.emoji-recent button').first().getAttribute('aria-label') ?? '', /большой палец средний тон/)
  await picker.getByRole('searchbox', { name: 'Поиск emoji' }).press('Escape')
  await openPicker()
  const first = picker.locator('.emoji-quick button').first()
  await first.focus(); await first.press('ArrowRight')
  assert.equal(await picker.locator('.emoji-quick button').nth(1).evaluate((element) => document.activeElement === element), true)
  await picker.locator('.emoji-quick button').nth(1).press('Enter')
  assert.equal(sends, 0)
  const contentWidth = await page.evaluate(() => document.documentElement.scrollWidth)
  assert.ok(contentWidth <= width, `horizontal overflow at ${width}`)
  results.push({ kind, viewport: [width, height], draft: await textarea.inputValue(), caret: await textarea.evaluate((element) => element.selectionStart), sends, errors, pickerBounds: bounds, contentWidth })
  await page.close()
}
writeFileSync(`${out}/emoji-probe.json`, `${JSON.stringify(results, null, 2)}\n`)
console.log(JSON.stringify(results, null, 2))
await browser.close()
server.kill()
