import { chromium } from '@playwright/test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { chatMembers, chatMessages, chatProfile, chatTopology } from './chat-reference-fixture.mjs'

const out = process.env.DESIGN_V2_ARTIFACT_DIR
if (!out) throw new Error('DESIGN_V2_ARTIFACT_DIR is required')
mkdirSync(out, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4182'], { stdio: 'ignore' })
process.on('exit', () => server.kill())
server.unref()
const url = 'http://127.0.0.1:4182/'
for (let attempt = 0; attempt < 50; attempt += 1) {
  try { if ((await fetch(url)).ok) break } catch { /* Vite is starting. */ }
  await new Promise((resolve) => setTimeout(resolve, 100))
}
const browser = await chromium.launch({ headless: true })
const name = 'ДарьяОченьДлинноеИмяБезПробелов🦊שלום'
const permissions = { 'channel.text.create': true, 'channel.text.delete': true, 'channel.voice.create': true,
  'channel.voice.delete': true, 'category.create': true, 'category.delete': true }
const results = []
for (const { width, avatar } of [{ width: 390, avatar: false }, { width: 320, avatar: false }, { width: 390, avatar: true }]) {
  const members = chatMembers.map((member) => member.user_id === 'daria-2' ? { ...member, display_name: name, presence: 'offline', avatar_url: avatar ? '/brand.png' : undefined } : member)
  const page = await browser.newPage({ viewport: { width, height: 844 } })
  const errors = []
  let dmOpens = 0; let sends = 0
  page.on('pageerror', (error) => errors.push(error.message))
  await page.route('**/api/v1/**', async (route) => {
    const path = new URL(route.request().url()).pathname
    let body = {}
    if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR' }
    else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR', permissions_revision: 1, permissions }
    else if (path.endsWith('/channels')) body = chatTopology
    else if (path.endsWith('/me')) body = chatProfile
    else if (path.endsWith('/members/daria-2')) body = members.find((member) => member.user_id === 'daria-2')
    else if (path.endsWith('/members')) body = { members }
    else if (path.endsWith('/direct-messages') && route.request().method() === 'POST') {
      assert.equal(JSON.parse(route.request().postData() ?? '{}').participant_id, 'daria-2')
      dmOpens += 1
      body = { id: 'dm-review', participant_one_id: chatProfile.account_id, participant_two_id: 'daria-2', created_at: '2026-10-03T10:00:00Z' }
    } else if (path.endsWith('/direct-messages')) body = { direct_messages: dmOpens ? [{ id: 'dm-review', other_participant_id: 'daria-2', other_participant_display_name: name, created_at: '2026-10-03T10:00:00Z', unread_count: 0, mention_count: 0 }] : [] }
    else if (path.includes('/messages')) { if (route.request().method() === 'POST') sends += 1; body = { messages: chatMessages } }
    else if (path.includes('/read-cursor')) body = { message_id: null }
    else if (path.includes('/maintenance')) body = { active: false }
    else if (path.includes('/client-updates')) body = { state: 'unconfigured', target: null }
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  })
  await page.goto(url, { waitUntil: 'domcontentloaded' })
  await page.getByRole('button', { name: 'Открыть участников' }).click()
  const trigger = page.locator('.members-guild-roster button.member').filter({ hasText: 'ДарьяОчень' })
  await trigger.click()
  const dialog = page.getByRole('dialog', { name: 'Профиль участника' })
  await dialog.getByRole('button', { name: 'Написать сообщение' }).waitFor()
  if (process.env.DESIGN_V2_BASELINE === '1') {
    await page.screenshot({ path: `${out}/${avatar ? 'member-avatar' : 'member-long-offline'}-${width}-before.png`, fullPage: true })
    await page.close(); continue
  }
  const bounds = await dialog.boundingBox()
  assert.ok(bounds && bounds.x === 0 && bounds.width === width && Math.round(bounds.y + bounds.height) === 844)
  assert.equal(await dialog.getAttribute('aria-modal'), 'true')
  assert.equal(await dialog.evaluate((element) => document.activeElement === element), true)
  assert.equal(await dialog.locator('h2').getAttribute('title'), name)
  assert.equal(await dialog.locator('.member-popover-identity').getAttribute('data-presence'), 'offline')
  if (avatar) {
    const rowImage = trigger.locator('img.member-avatar')
    const cardImage = dialog.locator('img.member-popover-avatar')
    assert.equal(await rowImage.getAttribute('src'), await cardImage.getAttribute('src'))
    assert.equal(await cardImage.evaluate((element) => element.complete && element.naturalWidth > 0), true)
  } else {
    const rowColor = await trigger.locator('.member-avatar').evaluate((element) => getComputedStyle(element).backgroundColor)
    const cardColor = await dialog.locator('.member-popover-avatar--empty').evaluate((element) => getComputedStyle(element).backgroundColor)
    assert.equal(cardColor, rowColor)
  }
  assert.equal(await dialog.locator('.member-popover-avatar-presence').evaluate((element) => getComputedStyle(element).backgroundColor), 'rgb(119, 128, 148)')
  const close = dialog.getByRole('button', { name: 'Закрыть профиль' })
  const closeBox = await close.boundingBox()
  assert.ok(closeBox && closeBox.width >= 44 && closeBox.height >= 44)
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth))
  await page.screenshot({ path: `${out}/${avatar ? 'member-avatar' : 'member-long-offline'}-${width}-actual.png`, fullPage: true })
  await dialog.press('Tab')
  assert.equal(await close.evaluate((element) => document.activeElement === element), true)
  await dialog.press('Escape')
  await dialog.waitFor({ state: 'detached' })
  assert.equal(await trigger.evaluate((element) => document.activeElement === element), true)
  assert.equal(await page.locator('.members-panel.is-open').count(), 1)
  await trigger.click(); await close.click(); await dialog.waitFor({ state: 'detached' })
  assert.equal(await trigger.evaluate((element) => document.activeElement === element), true)
  await trigger.click(); await page.mouse.click(20, 180); await dialog.waitFor({ state: 'detached' })
  assert.equal(await trigger.evaluate((element) => document.activeElement === element), true)
  if (width === 390) { await trigger.click(); await dialog.getByRole('button', { name: 'Написать сообщение' }).click(); await page.locator('.direct-message-conversation').waitFor(); assert.equal(dmOpens, 1) }
  assert.equal(sends, 0)
  assert.deepEqual(errors, [])
  results.push({ viewport: [width, 844], avatar, sheetBounds: bounds, closeTarget: closeBox, focusRestored: true, dmOpens, sends, errors })
  await page.close()
}
writeFileSync(`${out}/member-sheet-probe.json`, `${JSON.stringify(results, null, 2)}\n`)
console.log(JSON.stringify(results, null, 2))
await browser.close()
server.kill()
