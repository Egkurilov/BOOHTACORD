import assert from 'node:assert/strict'
import { chromium } from '@playwright/test'
import { chatMembers, chatMessages, chatProfile, chatTopology } from './chat-reference-fixture.mjs'
import { installReferenceTransports } from './reference-live-state.mjs'

const browser = await chromium.launch({ headless: true })
const page = await browser.newPage({ viewport: { width: 390, height: 844 } })
const pageErrors = []
page.on('pageerror', (error) => pageErrors.push(error.message))
await installReferenceTransports(page)

const dmMessages = chatMessages.slice(0, 2).map((message, index) => ({
  ...message, id: `dm-${index}`, direct_message_id: 'dm-daria', channel_id: undefined,
}))
await page.route('**/api/v1/**', async (route) => {
  const path = new URL(route.request().url()).pathname
  let body = {}
  if (path.endsWith('/auth/session')) body = { account_id: chatProfile.account_id, role: chatProfile.role }
  else if (path.endsWith('/auth/permissions')) body = { account_id: chatProfile.account_id, role: chatProfile.role, permissions_revision: 1, permissions: {} }
  else if (path.endsWith('/channels')) body = chatTopology
  else if (path.endsWith('/me')) body = chatProfile
  else if (path.endsWith('/members')) body = { members: chatMembers }
  else if (path.includes('/members/')) body = chatMembers.find((member) => path.endsWith(`/${member.user_id}`)) ?? {}
  else if (path.endsWith('/direct-messages')) body = { direct_messages: [{ id: 'dm-daria', other_participant_id: 'daria-2', other_participant_display_name: 'Daria', created_at: '2026-10-03T10:00:00Z', unread_count: 0, mention_count: 0 }] }
  else if (path.includes('/messages')) body = { messages: path.includes('/direct-messages/') ? dmMessages : chatMessages }
  else if (path.includes('/read-cursor')) body = { message_id: null }
  else if (path.includes('/maintenance')) body = { active: false }
  else if (path.includes('/client-updates')) body = { state: 'unconfigured', target: null }
  await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
})

async function verifyComposer(textareaSelector) {
  const textarea = page.locator(textareaSelector)
  await textarea.waitFor({ state: 'visible' })
  const trigger = page.getByRole('button', { name: 'Действия редактора' })
  await trigger.click()
  const menu = page.getByRole('group', { name: 'Действия редактора' })
  await menu.waitFor({ state: 'visible' })
  if (textareaSelector === '#message-body' && process.env.DESIGN_V2_MOBILE_ACTIONS_SCREENSHOT) await page.screenshot({ path: process.env.DESIGN_V2_MOBILE_ACTIONS_SCREENSHOT })
  for (const label of ['Прикрепить файл', 'Упомянуть', 'Emoji']) assert.equal(await menu.getByRole('button', { name: label }).count(), 1)
  await menu.getByRole('button', { name: 'Упомянуть' }).click()
  assert.equal(await textarea.inputValue(), '@')
  await textarea.fill('')
  await trigger.click()
  await menu.getByRole('button', { name: 'Emoji' }).click()
  await page.getByRole('button', { name: 'Добавить 😀' }).click()
  assert.equal(await textarea.inputValue(), '😀')
  await textarea.fill('')
  await trigger.click()
  const chooser = page.waitForEvent('filechooser')
  await menu.getByRole('button', { name: 'Прикрепить файл' }).click()
  await chooser
  assert.equal(await trigger.getAttribute('aria-expanded'), 'false')
  return { actions: ['filechooser', 'mention-autocomplete', 'emoji'], pageErrors: [...pageErrors] }
}

try {
  await page.goto(process.env.DESIGN_V2_URL ?? 'http://127.0.0.1:4175/', { waitUntil: 'domcontentloaded' })
  const channel = await verifyComposer('#message-body')
  await page.getByRole('button', { name: 'Открыть навигацию' }).click()
  await page.getByRole('button', { name: 'Личные', exact: true }).click()
  await page.locator('.direct-message-navigation .channel-button').filter({ hasText: 'Daria' }).click()
  const direct = await verifyComposer('#direct-message-body')
  await page.setViewportSize({ width: 1440, height: 900 })
  await page.getByRole('button', { name: 'Прикрепить файлы' }).waitFor({ state: 'visible' })
  assert.equal(await page.getByRole('button', { name: 'Выбрать упоминание' }).isVisible(), true)
  assert.equal(await page.getByRole('button', { name: 'Добавить emoji' }).isVisible(), true)
  assert.deepEqual(pageErrors, [])
  process.stdout.write(JSON.stringify({ channel, direct, desktopRestored: true }, null, 2))
} finally {
  await browser.close()
}
