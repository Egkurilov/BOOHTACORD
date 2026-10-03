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
  if (path.includes('/messages')) {
    const dm = path.includes('/direct-messages/')
    const samples = [
      { id: 'review-message-1', author_id: 'member-0', client_message_id: 'review-client-1', body: 'Кто сегодня играет вечером?', revision: 1, created_at: '2026-10-03T16:28:00Z', deleted: false, attachments: [], mention_user_ids: [] },
      { id: 'review-message-2', author_id: 'review-user', client_message_id: 'review-client-2', body: 'Я буду после восьми.', revision: 1, created_at: '2026-10-03T16:30:00Z', deleted: false, attachments: [], mention_user_ids: [] },
    ]
    return { messages: state === 'reply' ? [{ ...samples[0], id: 'reply-message', body: 'Давайте в 20:00', channel_id: 'text-1' }] : ['chat', 'dm'].includes(state) ? samples.map((item) => ({ ...item, ...(dm ? { direct_message_id: 'dm-review' } : { channel_id: 'text-1' }) })) : [] }
  }
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
await page.route('**/*', (route) => route.request().resourceType() === 'image' ? route.abort() : route.continue())
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
const needsNavigation = ['nav', 'roles', 'admin-members', 'audio', 'profile', 'search', 'topology-category', 'topology-channel'].includes(state)
if (width <= 1023 && needsNavigation) await page.getByRole('button', { name: 'Открыть навигацию' }).click()
if (['roles', 'admin-members'].includes(state)) await page.getByRole('button', { name: 'Моя гильдия' }).evaluate((button) => button.click())
const closeNavigation = async () => { const close = page.getByRole('button', { name: 'Закрыть навигацию' }); if (await close.count()) await close.evaluate((button) => button.click()) }
if (width <= 1023 && ['roles', 'admin-members'].includes(state)) await closeNavigation()
if (state === 'chat' && width > 600) await page.locator('.voice-dock').evaluate((element) => element.classList.add('connected'))
if ((process.argv[2] ?? 'chat') === 'roles') await page.getByRole('button', { name: 'Роли', exact: true }).click()
if ((process.argv[2] ?? 'chat') === 'admin-members') await page.getByRole('button', { name: 'Участники', exact: true }).click()
if (['chat', 'dm', 'reply'].includes(state)) await page.locator('.message-item').first().waitFor({ state: 'visible', timeout: 5000 }).catch(() => {})
if (state === 'context') await page.locator('.channel-category').first().evaluate((element) => element.dispatchEvent(new MouseEvent('contextmenu', { bubbles: true, clientX: 255, clientY: 235 })))
if (state === 'reply' && await page.locator('.message-actions-toggle').count()) { await page.locator('.message-actions-toggle').first().evaluate((button) => button.click()); await page.locator('.message-action-buttons button').first().evaluate((button) => button.click()); await page.locator('#message-body').fill('@Da'); await page.locator('.mention-popover').waitFor({ state: 'visible', timeout: 5000 }).catch(() => {}) }
if (state === 'audio') { await page.getByRole('button', { name: 'Настройки аудио' }).evaluate((button) => button.click()); await closeNavigation() }
if (state === 'profile') { await page.getByRole('button', { name: 'Открыть настройки профиля' }).evaluate((button) => button.click()); await closeNavigation() }
if (state === 'search') { await page.getByRole('button', { name: 'Поиск сообщений' }).click(); await closeNavigation() }
if (state === 'topology-category') { await page.getByRole('button', { name: 'Создать категорию или канал' }).click(); await closeNavigation() }
if (state === 'topology-channel') { await page.getByRole('button', { name: 'Создать канал в категории ОБЩЕНИЕ' }).click(); await closeNavigation() }
if (state === 'member-popover') { const member = page.locator('.members-guild-roster button.member').filter({ hasText: 'Daria' }); await member.waitFor(); await member.click() }
if (state === 'delete-confirm') await page.getByRole('button', { name: 'Действия с каналом общее' }).click()
if (state === 'dm') { await page.getByRole('button', { name: 'Личные', exact: true }).click(); await page.getByRole('button', { name: 'Daria', exact: true }).click() }
await page.waitForTimeout(state === 'update' ? 5500 : 100)
const selectors = ['.gc-shell', '.sidebar', '.sidebar.is-open', '.guild-header', '.nav-drawer', '.nav-content', '.drawer-scrim', '.mobile-voice-dock', '.voice-dock', '.user-footer', '.main', '.workspace-main-panel', '.workspace-main-panel--audio', '.workspace-main-panel--profile', '.workspace-header-actions', '.main-header', '.text-conversation', '.message-history-wrap', '.message-list', '.composer-wrap', '.composer', '.members-panel', '.channel-icon', '.channel-button.selected', '.nav-channel', '.section-head', '.message-item', '.message-avatar', '.message-body', '.attachment-card', '.gc-button', '.admin-panel', '.admin-panel-heading', '.admin-section-tabs', '.role-permissions', '.admin-section-heading', '.role-selector', '.role-permissions fieldset', '.role-permission-table-heading', '.role-permission-table', '.role-permission-table thead', '.role-permission-table tbody tr', '.role-permission-label', '.role-permission-label small', '.role-permission-notice', '.role-policy-actions', '.admin-directory', '.admin-table-scroll', '.admin-table', '.admin-table thead', '.admin-table tbody tr', '.admin-mobile-list', '.admin-mobile-card', '.admin-mobile-card summary', '.admin-mobile-user', '.admin-mobile-meta', '.audio-settings', '.audio-settings-panel', '.audio-device-section', '.audio-activation-section', '.audio-processing-section', '.profile-settings', '.profile-tabs', '.profile-panel', '.profile-settings .profile-form', '.profile-savebar', '.search-aside', '[data-testid="search-aside-panel"]', '[data-testid="search-panel"]', '.topology-dialog', '.admin-confirm-dialog', '.authentication-page', '.authentication-card', '.password-reset-card', '.member-popover', '.category-context-menu', '.update-banner', '.reply-target', '.mention-autocomplete', '.composer-helper', '.composer-wrap > *', '.mention-picker', '.mention-popover', '.direct-message-conversation', '.direct-message-conversation .message-history-wrap', '.direct-message-conversation .message-list', '.direct-message-conversation .composer-wrap', '.direct-message-conversation .composer', '.screen-stage', '.stream-quality-row', '.screen-rail-section', '.stream-diagnostics-panel', '.screen-share-setup-dialog', '.attachment-image-dialog', '.voice-participant-volumes', '.people-stage', '.members']
const boxes = Object.fromEntries(await Promise.all(selectors.map(async (selector) => {
  const locator = page.locator(selector).first()
  if (!await locator.count()) return [selector, null]
  const rect = await locator.boundingBox()
  return [selector, rect && Object.fromEntries(['x', 'y', 'width', 'height'].map((key) => [key, Math.round(rect[key] * 100) / 100]))]
})))
const visualProperties = ['display', 'position', 'boxSizing', 'width', 'height', 'paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft', 'gap', 'rowGap', 'columnGap', 'alignItems', 'justifyContent', 'flexDirection', 'fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing', 'color', 'backgroundColor', 'borderTopColor', 'borderTopWidth', 'borderRadius', 'boxShadow', 'opacity', 'overflowX', 'overflowY']
const styles = Object.fromEntries(await Promise.all(selectors.map(async (selector) => {
  const locator = page.locator(selector).first()
  if (!await locator.count()) return [selector, null]
  return [selector, await locator.evaluate((element, properties) => Object.fromEntries(properties.map((property) => [property, getComputedStyle(element)[property]])), visualProperties)]
})))
const composerChildren = []
console.log(JSON.stringify({ viewport: page.viewportSize(), state, boxes, styles, composerChildren, requests, errors }, null, 2))
await browser.close()
