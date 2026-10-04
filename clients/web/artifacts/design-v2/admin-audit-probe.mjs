import { chromium } from '@playwright/test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { chatMembers, chatProfile, chatTopology } from './chat-reference-fixture.mjs'

const out = process.env.DESIGN_V2_ARTIFACT_DIR
if (!out) throw new Error('DESIGN_V2_ARTIFACT_DIR is required')
mkdirSync(out, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4176'], { stdio: 'ignore' })
process.on('exit', () => server.kill())
server.unref()
const url = 'http://127.0.0.1:4176/'
for (let attempt = 0; attempt < 50; attempt += 1) {
  try { if ((await fetch(url)).ok) break } catch { /* Vite is starting. */ }
  await new Promise((resolve) => setTimeout(resolve, 100))
}
const browser = await chromium.launch({ headless: true })
const permissions = { 'channel.text.create': true, 'channel.text.delete': true, 'channel.voice.create': true,
  'channel.voice.delete': true, 'category.create': true, 'category.delete': true }
const owner = { actor_user_id: 'egor-2', actor_display_name: 'Егор', actor_login: 'egor' }
const other = { actor_user_id: 'alex-3', actor_display_name: 'Alex', actor_login: 'alex' }
const target = { target_user_id: 'daria-2', target_display_name: 'Daria', target_login: 'daria' }
const rows = [
  { id: 'a', event_type: 'VOICE_LEASE_KICKED', created_at: '2026-10-04T12:00:00Z', ...owner, ...target },
  { id: 'b', event_type: 'ACCOUNT_ADMIN_STATE_UPDATED', created_at: '2026-10-04T11:00:00Z', ...owner, ...target },
  { id: 'c', event_type: 'CHANNEL_RENAMED', created_at: '2026-10-03T15:00:00Z', ...other },
  { id: 'd', event_type: 'VOICE_LEASE_RELEASED', created_at: '2026-10-02T10:00:00Z', ...other },
]
const results = []
for (const [width, height] of [[1440, 900], [390, 844]]) {
  const page = await browser.newPage({ viewport: { width, height } })
  const errors = []
  const cursors = []
  page.on('pageerror', (error) => errors.push(error.message))
  await page.route('**/api/v1/**', async (route) => {
    const parsed = new URL(route.request().url())
    const path = parsed.pathname
    let body = {}
    if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR' }
    else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR', permissions_revision: 1, permissions }
    else if (path.endsWith('/channels')) body = chatTopology
    else if (path.endsWith('/me')) body = chatProfile
    else if (path.endsWith('/members')) body = { members: chatMembers }
    else if (path.endsWith('/direct-messages')) body = { direct_messages: [] }
    else if (path.endsWith('/admin/audit')) {
      cursors.push(parsed.searchParams.get('before'))
      body = parsed.searchParams.has('before') ? { events: [rows[2], rows[3]] } : { events: rows.slice(0, 3), next_cursor: 'cursor-2' }
    } else if (path.includes('/messages')) body = { messages: [] }
    else if (path.includes('/read-cursor')) body = { message_id: null }
    else if (path.includes('/maintenance')) body = { active: false }
    else if (path.includes('/client-updates')) body = { state: 'unconfigured', target: null }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  })
  await page.goto(url, { waitUntil: 'domcontentloaded' })
  await page.locator('.gc-shell').waitFor()
  if (width < 1024) await page.getByRole('button', { name: 'Открыть навигацию' }).click()
  await page.getByRole('button', { name: 'Моя гильдия' }).evaluate((button) => button.click())
  if (width < 1024 && await page.getByRole('button', { name: 'Закрыть навигацию' }).count()) {
    await page.getByRole('button', { name: 'Закрыть навигацию' }).evaluate((button) => button.click())
  }
  await page.locator('[data-testid="admin-panel"]').getByRole('button', { name: 'Аудит', exact: true }).click()
  await page.locator('.audit-event-list li').first().waitFor()
  await page.locator('.audit-event-list li').first().getByText('Детали события').click()
  await page.locator('.audit-event-list li').first().getByText('VOICE_LEASE_KICKED').waitFor()
  await page.screenshot({ path: `${out}/admin-audit-${width}-actual.png`, fullPage: true })
  await page.getByRole('button', { name: 'Показать более ранние' }).click()
  await page.getByText('4 загруженным записям').waitFor()
  assert.equal(await page.locator('.audit-event-list li').count(), 4)
  assert.deepEqual(cursors, [null, 'cursor-2'])
  await page.getByRole('combobox', { name: 'Область' }).selectOption('voice')
  assert.equal(await page.locator('.audit-event-list li').count(), 2)
  await page.getByRole('combobox', { name: 'Область' }).selectOption('admin')
  assert.equal(await page.locator('.audit-event-list li').count(), 2)
  await page.getByRole('combobox', { name: 'Область' }).selectOption('all')
  await page.getByRole('textbox', { name: 'С даты' }).fill('2026-10-04')
  await page.getByRole('textbox', { name: 'По дату' }).fill('2026-10-04')
  assert.equal(await page.locator('.audit-event-list li').count(), 2)
  await page.getByRole('combobox', { name: 'Действие' }).selectOption('ACCOUNT_ADMIN_STATE_UPDATED')
  await page.getByRole('combobox', { name: 'Инициатор' }).selectOption('egor-2')
  assert.equal(await page.locator('.audit-event-list li').count(), 1)
  await page.screenshot({ path: `${out}/admin-audit-${width}-filtered-actual.png`, fullPage: true })
  const contentWidth = await page.evaluate(() => document.documentElement.scrollWidth)
  assert.ok(contentWidth <= width, `horizontal overflow at ${width}: ${contentWidth}`)
  results.push({ viewport: [width, height], loaded: 4, filtered: 1, cursors, errors, contentWidth })
  await page.close()
}
writeFileSync(`${out}/admin-audit-probe.json`, `${JSON.stringify(results, null, 2)}\n`)
console.log(JSON.stringify(results, null, 2))
await browser.close()
server.kill()
