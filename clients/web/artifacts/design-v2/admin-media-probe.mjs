import { chromium } from '@playwright/test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { chatMembers, chatProfile, chatTopology } from './chat-reference-fixture.mjs'

const out = process.env.DESIGN_V2_ARTIFACT_DIR
if (!out) throw new Error('DESIGN_V2_ARTIFACT_DIR is required')
mkdirSync(out, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4177'], { stdio: 'ignore' })
process.on('exit', () => server.kill())
server.unref()
const url = 'http://127.0.0.1:4177/'
for (let attempt = 0; attempt < 50; attempt += 1) {
  try { if ((await fetch(url)).ok) break } catch { /* Vite is starting. */ }
  await new Promise((resolve) => setTimeout(resolve, 100))
}
const browser = await chromium.launch({ headless: true })
const permissions = { 'channel.text.create': true, 'channel.text.delete': true, 'channel.voice.create': true,
  'channel.voice.delete': true, 'category.create': true, 'category.delete': true }
const freshTime = new Date().toISOString()
const staleTime = new Date(Date.now() - 120_000).toISOString()
const report = (platform, direction, at) => ({ sampled_at_utc: at, report: {
  platform, direction, state: 'playing', frame_width: 1280, frame_height: 720,
  encoded_fps: direction === 'sender' ? 30 : undefined,
  decoded_fps: direction === 'receiver' ? 28 : undefined,
  presented_fps: direction === 'receiver' ? 27 : undefined,
  bitrate_kbps: 1800,
} })
const results = []
for (const [width, height] of [[1440, 900], [390, 844]]) {
  for (const state of ['empty', 'populated', 'stale', 'error']) {
    const page = await browser.newPage({ viewport: { width, height } })
    const errors = []
    page.on('pageerror', (error) => errors.push(error.message))
    await page.route('**/api/v1/**', async (route) => {
      const path = new URL(route.request().url()).pathname
      let body = {}
      if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR' }
      else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR', permissions_revision: 1, permissions }
      else if (path.endsWith('/channels')) body = chatTopology
      else if (path.endsWith('/me')) body = chatProfile
      else if (path.endsWith('/members')) body = { members: chatMembers }
      else if (path.endsWith('/direct-messages')) body = { direct_messages: [] }
      else if (path.endsWith('/admin/screen-metrics')) {
        if (state === 'error') { await route.fulfill({ status: 503, contentType: 'application/json', body: '{}' }); return }
        const at = state === 'stale' ? staleTime : freshTime
        body = { samples: state === 'empty' ? [] : [report('desktop_web', 'sender', at), report('ios_web', 'receiver', at)] }
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
    await page.locator('[data-testid="admin-panel"]').getByRole('button', { name: 'Медиа', exact: true }).click()
    await page.locator('.admin-media-freshness strong').getByText({ empty: 'Нет данных', populated: 'Есть измерения', stale: 'Данные устарели', error: 'Ошибка обновления' }[state]).waitFor()
    if (state === 'empty') await page.locator('.admin-media-freshness').getByText(/Успешно обновлено:/).waitFor()
    if (state === 'populated') {
      assert.equal(await page.locator('.admin-media-sample').count(), 2)
      assert.equal(await page.locator('.admin-media-freshness').getByText('Свежих отчётов: 2').count(), 1)
    }
    if (state === 'empty') assert.equal(await page.locator('.admin-media-empty li').count(), 3)
    if (state === 'stale') assert.equal(await page.locator('.admin-media-sample').count(), 0)
    if (state === 'error') assert.equal(await page.locator('.admin-error').count(), 1)
    assert.equal(await page.locator('.admin-media-diagnostics').locator('[data-account-id], [data-user-id]').count(), 0)
    await page.screenshot({ path: `${out}/admin-media-${width}-${state}-actual.png`, fullPage: true })
    const contentWidth = await page.evaluate(() => document.documentElement.scrollWidth)
    assert.ok(contentWidth <= width, `horizontal overflow at ${width}: ${contentWidth}`)
    results.push({ viewport: [width, height], state, errors, contentWidth })
    await page.close()
  }
}
writeFileSync(`${out}/admin-media-probe.json`, `${JSON.stringify(results, null, 2)}\n`)
console.log(JSON.stringify(results, null, 2))
await browser.close()
server.kill()
