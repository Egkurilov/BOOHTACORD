import { chromium } from '@playwright/test'

const profile = { account_id: 'review-user', login: 'review', display_name: 'Review User', role: 'ADMINISTRATOR' }
const permissions = {
  'channel.text.create': true, 'channel.text.delete': true,
  'channel.voice.create': true, 'channel.voice.delete': true,
  'category.create': true, 'category.delete': true,
}
const topology = { revision: 1, categories: [{ id: 'category-1', name: 'ОБЩЕНИЕ', position: 0, channels: [
  { id: 'text-1', name: 'общее', kind: 'TEXT', position: 0, admission_closed: false, unread_count: 0, mention_count: 0 },
  { id: 'voice-1', name: 'Общий', kind: 'VOICE', position: 1, admission_closed: false },
]}] }
const fixtureMember = { user_id: 'review-user', login: 'review', display_name: 'Review User', role: 'ADMINISTRATOR', presence: 'online' }
const reviewMember = { user_id: 'member-0', login: 'daria', display_name: 'Daria', role: 'MEMBER', presence: 'online' }
const accounts = [{ ...fixtureMember, account_id: fixtureMember.user_id }, ...['Alex', 'Daria', 'Max', 'Nika', 'Sergey'].map((name, index) => ({
  account_id: `member-${index}`, login: name.toLowerCase(), display_name: name,
  role: 'MEMBER', blocked: false, created_at: '2026-10-03T10:00:00Z',
}))].map((item) => ({ blocked: false, created_at: '2026-10-03T10:00:00Z', ...item }))

function response(path) {
  if (path.endsWith('/auth/session')) return { account_id: profile.account_id, role: profile.role }
  if (path.endsWith('/auth/permissions')) return { account_id: profile.account_id, role: profile.role, permissions_revision: 1, permissions }
  if (path.endsWith('/channels')) return topology
  if (path.endsWith('/me')) return profile
  if (path.endsWith('/members')) return { members: [reviewMember, fixtureMember] }
  if (path.endsWith('/members/member-0')) return reviewMember
  if (path.includes('/admin/accounts')) return { accounts }
  if (path.includes('/admin/roles')) return { revision: 1, roles: [
    { role: 'MEMBER', display_name: 'Участник', editable: true, permissions },
    { role: 'ADMINISTRATOR', display_name: 'Администратор', editable: false, permissions },
  ] }
  if (path.endsWith('/direct-messages')) return { direct_messages: [{ id: 'dm-review', other_participant_id: 'member-0', other_participant_display_name: 'Daria', created_at: '2026-10-03T10:00:00Z', unread_count: 0, mention_count: 0 }] }
  if (path.includes('/messages')) return { messages: state === 'reply' ? [{ id: 'reply-message', channel_id: 'text-1', author_id: 'member-0', client_message_id: 'reply-client', body: 'Давайте в 20:00', revision: 1, created_at: '2026-10-03T16:00:00Z', deleted: false, attachments: [], mention_user_ids: [] }] : [] }
  if (path.includes('/read-cursor')) return { message_id: null }
  if (path.includes('/maintenance')) return { active: false }
  if (state === 'update' && path.includes('/client-updates')) return { application_family: 'boohtacord', catalog_revision: 1, platform: 'web', distribution: 'browser', channel: 'stable', arch: 'any', state: 'published', target: { release_id: 'design-review-release', release_order: 999, version: '99.0.0', native_build: null, priority: 'normal', requirements: { supported_arches: ['any'] }, action: { kind: 'reload', url: null }, release_notes_url: null, summary: 'Доступен новый выпуск.' } }
  if (path.includes('/client-updates')) return { state: 'unconfigured', target: null }
  return {}
}

const browser = await chromium.launch({ headless: true })
const state = process.argv[2] ?? 'chat'
const width = Number(process.argv[3] ?? 1440)
const height = Number(process.argv[4] ?? 900)
const page = await browser.newPage({ viewport: { width, height } })
const requests = []; const errors = []
page.on('pageerror', (error) => errors.push(error.message))
page.on('request', (request) => { if (request.url().includes('/api/v1/')) requests.push(`${request.method()} ${new URL(request.url()).pathname}`) })
await page.route('**/api/v1/**', async (route) => {
  const path = new URL(route.request().url()).pathname
  const status = state === 'auth' && path.endsWith('/auth/session') ? 401 : 200
  await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(response(path)) })
})
const url = state === 'reset' ? 'http://127.0.0.1:4173/reset-password' : process.env.DESIGN_V2_URL ?? 'http://127.0.0.1:4173'
await page.goto(url, { waitUntil: 'domcontentloaded' })
await page.locator('.gc-shell, .authentication-page').first().waitFor({ state: 'visible' })
if (width <= 1023 && !['auth', 'reset'].includes(state)) await page.getByRole('button', { name: 'Открыть навигацию' }).click()
if (!['audio', 'profile', 'search', 'nav', 'member-popover', 'topology-category', 'topology-channel', 'delete-confirm', 'dm', 'auth', 'reset', 'reply', 'update'].includes(state)) await page.getByRole('button', { name: 'Моя гильдия' }).evaluate((button) => button.click())
if ((process.argv[2] ?? 'chat') === 'roles') await page.getByRole('button', { name: 'Роли', exact: true }).click()
if ((process.argv[2] ?? 'chat') === 'admin-members') await page.getByRole('button', { name: 'Участники', exact: true }).click()
if (state === 'reply' && await page.locator('.message-actions-toggle').count()) { await page.locator('.message-actions-toggle').first().evaluate((button) => button.click()); await page.locator('.message-action-buttons button').first().evaluate((button) => button.click()) }
if (state === 'audio') await page.getByRole('button', { name: 'Настройки аудио' }).evaluate((button) => button.click())
if (state === 'profile') await page.getByRole('button', { name: 'Открыть настройки профиля' }).evaluate((button) => button.click())
if ((process.argv[2] ?? 'chat') === 'search') await page.getByRole('button', { name: 'Поиск сообщений' }).click()
if (state === 'topology-category') await page.getByRole('button', { name: 'Создать категорию или канал' }).click()
if (state === 'topology-channel') await page.getByRole('button', { name: 'Создать канал в категории ОБЩЕНИЕ' }).click()
if (state === 'member-popover') { const member = page.locator('.members-guild-roster button.member').filter({ hasText: 'Daria' }); await member.waitFor(); await member.click() }
if (state === 'delete-confirm') await page.getByRole('button', { name: 'Действия с каналом общее' }).click()
if (state === 'dm') { await page.getByRole('button', { name: 'Личные', exact: true }).click(); await page.getByRole('button', { name: 'Daria', exact: true }).click() }
await page.waitForTimeout(state === 'update' ? 5500 : 100)
const selectors = ['.gc-shell', '.sidebar', '.nav-drawer', '.drawer-scrim', '.mobile-voice-dock', '.main', '.workspace-main-panel', '.workspace-main-panel--audio', '.workspace-main-panel--profile', '.workspace-header-actions', '.admin-panel', '.admin-panel-heading', '.admin-section-tabs', '.role-permissions', '.admin-section-heading', '.role-selector', '.role-permissions fieldset', '.role-permission-table-heading', '.role-permission-table', '.role-permission-table thead', '.role-permission-table tbody tr', '.role-permission-label', '.role-permission-label small', '.role-permission-notice', '.role-policy-actions', '.admin-directory', '.admin-table-scroll', '.admin-table', '.admin-table thead', '.admin-table tbody tr', '.admin-mobile-list', '.admin-mobile-card', '.admin-mobile-card summary', '.admin-mobile-user', '.admin-mobile-meta', '.audio-settings', '.audio-settings-panel', '.audio-device-section', '.audio-activation-section', '.audio-processing-section', '.profile-settings', '.profile-tabs', '.profile-panel', '.profile-settings .profile-form', '.profile-savebar', '[data-testid="search-aside-panel"]', '[data-testid="search-panel"]', '.topology-dialog', '.admin-confirm-dialog', '.authentication-page', '.authentication-card', '.password-reset-card', '.member-popover', '.update-banner', '.reply-target', '.text-conversation .composer-wrap', '.text-conversation .composer', '.direct-message-conversation', '.direct-message-conversation .message-history-wrap', '.direct-message-conversation .composer-wrap', '.direct-message-conversation .composer', '.members']
const boxes = Object.fromEntries(await Promise.all(selectors.map(async (selector) => {
  const locator = page.locator(selector).first()
  if (!await locator.count()) return [selector, null]
  const rect = await locator.boundingBox()
  return [selector, rect && Object.fromEntries(['x', 'y', 'width', 'height'].map((key) => [key, Math.round(rect[key] * 100) / 100]))]
})))
console.log(JSON.stringify({ viewport: page.viewportSize(), state: process.argv[2] ?? 'members', boxes, requests, errors, text: await page.locator('.admin-directory').innerText().catch(() => ''), mainText: await page.locator('.main').innerText().catch(() => '') }, null, 2))
await browser.close()
