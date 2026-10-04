import { chromium } from '@playwright/test'
import assert from 'node:assert/strict'
import { spawn } from 'node:child_process'
import { mkdirSync, writeFileSync } from 'node:fs'
import { chatMembers, chatProfile, chatTopology } from './chat-reference-fixture.mjs'

const out = process.env.DESIGN_V2_ARTIFACT_DIR
if (!out) throw new Error('DESIGN_V2_ARTIFACT_DIR is required')
mkdirSync(out, { recursive: true })
const server = spawn(process.execPath, ['node_modules/vite/bin/vite.js', '--host', '127.0.0.1', '--port', '4175'], { stdio: 'ignore' })
process.on('exit', () => server.kill())
server.unref()
const url = process.env.DESIGN_V2_URL ?? 'http://127.0.0.1:4175/'
for (let attempt = 0; attempt < 50; attempt += 1) {
  try { if ((await fetch(url)).ok) break } catch { /* Vite is starting. */ }
  await new Promise((resolve) => setTimeout(resolve, 100))
}
const browser = await chromium.launch({ headless: true })
const permissions = {
  'channel.text.create': true, 'channel.text.delete': true, 'channel.voice.create': true,
  'channel.voice.delete': true, 'category.create': true, 'category.delete': true,
}
const results = []
for (const [width, height] of [[1440, 900], [390, 844]]) {
  const page = await browser.newPage({ viewport: { width, height } })
  const errors = []
  const mutations = []
  page.on('pageerror', (error) => errors.push(error.message))
  await page.route('**/api/v1/**', async (route) => {
    const path = new URL(route.request().url()).pathname
    const method = route.request().method()
    let body = {}
    if (method !== 'GET') {
      if (path.includes('/admin/')) mutations.push({ method, path, payload: JSON.parse(route.request().postData() ?? '{}') })
      if (path.endsWith('/channels/voice-2') && method === 'PATCH') body = { id: 'voice-2', name: 'Играем заново', revision: 2 }
      else if (path.endsWith('/channels/voice-2/category')) body = { id: 'voice-2', category_id: 'development', position: 0, revision: 2 }
      else if (path.endsWith('/channels/order')) body = { revision: 2 }
      else body = { topology_revision: 2, result: { resource_type: 'VOICE_CHANNEL', resource_id: 'voice-2', state: 'ACTIVE' } }
    } else if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR' }
    else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: 'ADMINISTRATOR', permissions_revision: 1, permissions }
    else if (path.endsWith('/channels')) body = chatTopology
    else if (path.endsWith('/me')) body = chatProfile
    else if (path.endsWith('/members')) body = { members: chatMembers }
    else if (path.endsWith('/direct-messages')) body = { direct_messages: [] }
    else if (path.includes('/messages')) body = { messages: [] }
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
  await page.locator('[data-testid="admin-panel"]').getByRole('button', { name: 'Каналы', exact: true }).click()
  await page.locator('.admin-topology-inspector').waitFor()
  await page.screenshot({ path: `${out}/admin-channels-${width}-category-actual.png`, fullPage: true })
  await page.getByRole('button', { name: 'Выбрать голосовой канал Играем' }).click()
  assert.equal(await page.locator('.admin-topology-inspector > header h3').textContent(), 'Играем')
  assert.equal(await page.locator('.admin-topology-inspector select[name=rename-channel]').count(), 0)
  assert.equal(await page.locator('.admin-topology-inspector select[name=move-channel]').count(), 0)
  assert.equal(await page.locator('.admin-topology-inspector select[name=order-channel]').count(), 0)
  const contentWidth = await page.evaluate(() => document.documentElement.scrollWidth)
  assert.ok(contentWidth <= width, `horizontal overflow at ${width}: ${contentWidth}`)
  await page.screenshot({ path: `${out}/admin-channels-${width}-voice-actual.png`, fullPage: true })
  await page.getByRole('button', { name: 'Закрыть вход', exact: true }).click()
  const dialog = page.getByRole('dialog', { name: 'Подтверждение закрытия' })
  await dialog.waitFor({ state: 'visible' })
  await dialog.getByRole('button', { name: 'Отмена' }).click()
  assert.equal(mutations.filter((item) => item.path.includes('/close-admission')).length, 0)
  await page.getByRole('textbox', { name: 'Новое имя канала' }).fill('Играем заново')
  await page.getByRole('button', { name: 'Переименовать канал' }).click()
  await page.getByText('Канал переименован. Обновляем список.').waitFor()
  assert.ok(mutations.some((item) => item.path.endsWith('/channels/voice-2') && item.payload.expected_revision === 1))
  await page.getByRole('combobox', { name: 'В категорию' }).selectOption('development')
  await page.getByRole('button', { name: 'Перенести канал' }).click()
  await page.getByText('Канал перенесён. Обновляем список.').waitFor()
  assert.ok(mutations.some((item) => item.path.endsWith('/channels/voice-2/category') && item.payload.category_id === 'development'))
  await page.getByRole('button', { name: 'Переместить канал «Играем» выше' }).press('Enter')
  assert.ok(mutations.some((item) => item.path.endsWith('/categories/voice/channels/order') && item.payload.expected_revision === 1))
  await page.getByText('Порядок каналов сохранён. Обновляем список.').waitFor()
  const result = { viewport: [width, height], selectedChannel: 'voice-2', mutations, errors, contentWidth }
  results.push(result)
  await page.close()
}
writeFileSync(`${out}/admin-channels-probe.json`, `${JSON.stringify(results, null, 2)}\n`)
console.log(JSON.stringify(results, null, 2))
await browser.close()
server.kill()
