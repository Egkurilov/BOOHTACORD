import { chromium } from '@playwright/test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { chatMembers, chatMessages, chatProfile, chatTopology } from './chat-reference-fixture.mjs'
import { connectReferenceVoiceStore, installReferenceTransports } from './reference-live-state.mjs'
import { measureDom } from './dom-probe-measure.mjs'

const profile = { account_id: 'review-user', login: 'review', display_name: 'Review User', role: 'ADMINISTRATOR' }
const permissions = {
  'channel.text.create': true, 'channel.text.delete': true,
  'channel.voice.create': true, 'channel.voice.delete': true,
  'category.create': true, 'category.delete': true,
}
let memberPermissions = {
  'channel.text.create': true, 'channel.text.delete': false,
  'channel.voice.create': true, 'channel.voice.delete': false,
  'category.create': true, 'category.delete': false,
}
let roleRevision = 1
let createdChannel = null
let profileDisplayName = 'Егор'
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
  if (path.endsWith('/auth/session')) return { account_id: referenceFixture ? chatProfile.account_id : profile.account_id, role: profile.role }
  if (path.endsWith('/auth/permissions')) return { account_id: referenceFixture ? chatProfile.account_id : profile.account_id, role: profile.role, permissions_revision: 1, permissions }
  if (path.endsWith('/channels')) return referenceFixture ? chatTopology : topology
  if (path.endsWith('/me')) return referenceFixture ? state === 'profile' ? { ...chatProfile, login: 'owner', display_name: profileDisplayName } : chatProfile : profile
  if (path.endsWith('/members')) return { members: referenceFixture ? chatMembers : [reviewMember, fixtureMember] }
  if (referenceFixture && path.includes('/members/')) return chatMembers.find((member) => path.endsWith(`/${member.user_id}`)) ?? {}
  if (path.endsWith('/members/member-0')) return reviewMember
  if (path.includes('/admin/accounts')) return { accounts }
  if (path.includes('/admin/roles')) return { revision: roleRevision, roles: [
    { role: 'MEMBER', display_name: 'Участник', editable: true, permissions: memberPermissions },
    { role: 'ADMINISTRATOR', display_name: 'Администратор', editable: false, permissions },
  ] }
  if (path.endsWith('/direct-messages')) return { direct_messages: [{ id: 'dm-review', other_participant_id: 'member-0', other_participant_display_name: 'Daria', created_at: '2026-10-03T10:00:00Z', unread_count: 0, mention_count: 0 }] }
  if (path.includes('/messages')) {
    if (referenceFixture) return { messages: chatMessages }
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
const referenceFixture = process.env.DESIGN_V2_REFERENCE_FIXTURE === '1' && ['chat', 'roles', 'topology-channel', 'audio', 'profile'].includes(state)
const width = Number(process.argv[3] ?? 1440)
const height = Number(process.argv[4] ?? 900)
const screenshotPath = process.env.DESIGN_V2_SCREENSHOT
const page = await browser.newPage({ viewport: { width, height } })
if (referenceFixture && process.env.DESIGN_V2_LIVE_STATE === '1') await installReferenceTransports(page)
if (referenceFixture && state === 'audio') await page.addInitScript(() => {
  const devices = [
    { kind: 'audioinput', deviceId: 'default', label: 'USB Audio Device', groupId: 'input' },
    { kind: 'audiooutput', deviceId: 'default', label: 'Системное устройство', groupId: 'output' },
  ]
  Object.defineProperty(navigator.mediaDevices, 'enumerateDevices', { configurable: true, value: async () => devices })
})
await page.route('**/*', (route) => !screenshotPath && route.request().resourceType() === 'image' ? route.abort() : route.continue())
const requests = []; const errors = []
page.on('pageerror', (error) => errors.push(error.message))
page.on('request', (request) => { if (request.url().includes('/api/v1/')) requests.push(`${request.method()} ${new URL(request.url()).pathname}`) })
await page.route('**/api/v1/**', async (route) => {
  const path = new URL(route.request().url()).pathname
  if (path.endsWith('/admin/roles/MEMBER/permissions') && route.request().method() === 'PUT') {
    const body = JSON.parse(route.request().postData() ?? '{}')
    assert.equal(body.expected_revision, roleRevision)
    assert.equal(body.confirm_delete_grants, false)
    memberPermissions = body.permissions
    roleRevision += 1
    await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }); return
  }
  if (path.endsWith('/categories/chat/channels') && route.request().method() === 'POST') {
    createdChannel = JSON.parse(route.request().postData() ?? '{}')
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ client_request_id: createdChannel.client_request_id, topology_revision: 2, result: { resource_type: 'TEXT_CHANNEL', resource_id: 'new-channel', state: 'ACTIVE' } }) }); return
  }
  if (state === 'profile' && path.endsWith('/me') && route.request().method() === 'PATCH') {
    profileDisplayName = JSON.parse(route.request().postData() ?? '{}').display_name
    await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(response(path)) }); return
  }
  if (referenceFixture && path.endsWith('/attachments/scene/preview') && process.env.DESIGN_V2_SCENE_PNG) {
    await route.fulfill({ contentType: 'image/png', body: readFileSync(process.env.DESIGN_V2_SCENE_PNG) }); return
  }
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
if (state === 'topology-channel') { await page.getByRole('button', { name: 'Создать канал в категории ОБЩЕНИЕ' }).click(); await closeNavigation(); if (referenceFixture) await page.getByRole('textbox', { name: 'Название канала' }).fill('вечерние-заезды') }
if (state === 'member-popover') { const member = page.locator('.members-guild-roster button.member').filter({ hasText: 'Daria' }); await member.waitFor(); await member.click() }
if (state === 'delete-confirm') await page.getByRole('button', { name: 'Действия с каналом общее' }).click()
if (state === 'dm') { await page.getByRole('button', { name: 'Личные', exact: true }).click(); await page.getByRole('button', { name: 'Daria', exact: true }).click() }
if (referenceFixture && state === 'topology-channel') await page.waitForFunction(() => { const image = document.querySelector('.attachment-card__preview'); return image instanceof HTMLImageElement && image.complete && image.naturalWidth > 0 })
await page.waitForTimeout(state === 'update' ? 5500 : 100)
if (referenceFixture && ['roles', 'topology-channel', 'audio', 'profile'].includes(state) && process.env.DESIGN_V2_LIVE_STATE === '1') await connectReferenceVoiceStore(page)
if (referenceFixture && state === 'chat') {
  await page.locator('.message-item').nth(3).waitFor({ state: 'visible' })
  await page.waitForFunction(() => { const image = document.querySelector('.attachment-card__preview'); return image instanceof HTMLImageElement && image.complete && image.naturalWidth > 0 })
  if (process.env.DESIGN_V2_LIVE_STATE === '1') await connectReferenceVoiceStore(page)
  await page.evaluate(() => document.fonts.ready)
  if (process.env.DESIGN_V2_VERIFY_INTERACTIONS === '1') {
    await page.getByRole('button', { name: 'Открыть изображение evening-session.png' }).click()
    const viewer = page.getByRole('dialog', { name: 'Просмотр изображения evening-session.png' })
    await viewer.waitFor({ state: 'visible' })
    await viewer.locator('img').waitFor({ state: 'visible' })
    await viewer.getByRole('button', { name: 'Закрыть просмотр изображения' }).click()
    await viewer.waitFor({ state: 'hidden' })
    await page.locator('#message-body').fill('Проверка отправки')
    if (!await page.getByRole('button', { name: 'Отправить сообщение' }).isEnabled()) throw new Error('Composer send did not enable for a nonempty message')
    await page.locator('#message-body').fill('')
  }
}
if (state === 'chat' && (await Promise.all((await page.locator('dialog:not([open])').all()).map((dialog) => dialog.isVisible()))).some(Boolean)) throw new Error('Closed native dialog is visibly rendered')
await page.mouse.move(width - 2, 55)
if (screenshotPath) await page.screenshot({ path: screenshotPath, animations: 'disabled' })
const { boxes, styles, composerChildren } = await measureDom(page)
const interactions = []
if (state === 'roles' && process.env.DESIGN_V2_VERIFY_INTERACTIONS === '1') {
  const createText = page.getByRole('checkbox', { name: 'Создавать текстовые каналы' })
  assert.equal(await createText.isChecked(), true)
  await createText.uncheck()
  assert.equal(await page.getByRole('button', { name: 'Сохранить' }).isEnabled(), true)
  await page.getByRole('button', { name: 'Сохранить' }).click()
  await page.getByText('Разрешения участников сохранены.').waitFor()
  assert.equal(memberPermissions['channel.text.create'], false)
  interactions.push('member-draft-save')
  await page.getByRole('tab', { name: 'Администратор' }).click()
  assert.equal(await createText.isDisabled(), true)
  interactions.push('administrator-lock')
  await page.getByRole('button', { name: 'Закрыть администрирование' }).click()
  await page.locator('.workspace-main-panel--admin').waitFor({ state: 'detached' })
  interactions.push('close-returns-to-workspace')
}
if (state === 'topology-channel' && process.env.DESIGN_V2_VERIFY_INTERACTIONS === '1') {
  const voice = page.getByRole('button', { name: 'Голосовой' })
  await voice.click()
  assert.equal(await voice.getAttribute('aria-pressed'), 'true')
  await page.getByRole('button', { name: 'Текстовый' }).click()
  await page.getByRole('button', { name: 'Создать канал', exact: true }).click()
  await page.getByRole('dialog', { name: 'Создать канал' }).waitFor({ state: 'detached' })
  assert.equal(createdChannel?.name, 'вечерние-заезды')
  assert.equal(createdChannel?.kind, 'TEXT')
  assert.equal(typeof createdChannel?.client_request_id, 'string')
  interactions.push('kind-toggle', 'text-channel-mutation', 'dialog-closes-on-success')
}
if (state === 'audio' && process.env.DESIGN_V2_VERIFY_INTERACTIONS === '1') {
  const microphone = page.getByRole('combobox', { name: 'Микрофон' })
  assert.equal(await microphone.inputValue(), 'default')
  assert.equal(await microphone.locator('option:checked').textContent(), 'USB Audio Device')
  interactions.push('enumerated-microphone')
  const ptt = page.getByRole('button', { name: 'По нажатию' })
  await ptt.click()
  assert.equal(await ptt.getAttribute('aria-pressed'), 'true')
  await page.getByRole('button', { name: 'Назначить PTT-клавишу' }).waitFor({ state: 'visible' })
  await page.getByRole('button', { name: 'По голосу' }).click()
  interactions.push('activation-mode-switch')
  await page.getByText('Режим и диагностика обработки').click()
  await page.getByRole('combobox', { name: 'Режим шумоподавления' }).waitFor({ state: 'visible' })
  interactions.push('processing-options-preserved')
  await page.getByRole('button', { name: 'Закрыть настройки аудио' }).click()
  await page.locator('.workspace-main-panel--audio').waitFor({ state: 'detached' })
  interactions.push('close-returns-to-workspace')
}
if (state === 'profile' && process.env.DESIGN_V2_VERIFY_INTERACTIONS === '1') {
  await page.getByRole('textbox', { name: 'Отображаемое имя' }).fill('Егор Тест')
  await page.getByRole('button', { name: 'Сохранить профиль' }).click()
  await page.getByText('Имя профиля сохранено.').waitFor()
  assert.equal(profileDisplayName, 'Егор Тест')
  interactions.push('profile-name-patch')
  await page.getByRole('tab', { name: 'Безопасность' }).click()
  await page.getByLabel('Текущий пароль').waitFor({ state: 'visible' })
  interactions.push('security-tab-preserved')
  await page.getByRole('button', { name: 'Закрыть настройки', exact: true }).click()
  await page.locator('.workspace-main-panel--profile').waitFor({ state: 'detached' })
  interactions.push('close-returns-to-workspace')
}
console.log(JSON.stringify({ viewport: page.viewportSize(), state, boxes, styles, composerChildren, requests, errors, interactions }, null, 2))
await browser.close()
