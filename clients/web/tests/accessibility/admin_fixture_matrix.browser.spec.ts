import { expect, test } from '@playwright/test'

test('admin tabs retain useful state across staged 200/403/409/503 responses', async ({ page }) => {
  type Fault = 200 | 403 | 409 | 503
  let fault: Fault = 200
  let memberRole: 'MEMBER' | 'ADMINISTRATOR' = 'MEMBER'
  let patchRequests = 0
  let holdNextPatch = false
  let releasePatch!: () => void
  let beginHeldPatch!: () => void
  const heldPatchStarted = new Promise<void>(resolve => { beginHeldPatch = resolve })
  const permissions = {
    'channel.text.create': true, 'channel.text.delete': false,
    'channel.voice.create': true, 'channel.voice.delete': false,
    'category.create': true, 'category.delete': false,
  }
  const account = {
    account_id: '11111111-1111-4111-8111-111111111111', login: 'member', display_name: 'Участник',
    role: 'MEMBER', blocked: false, created_at: '2026-10-01T12:00:00Z', updated_at: '2026-10-01T12:00:00Z',
  }
  const roles = { revision: 1, roles: [
    { role: 'ADMINISTRATOR', display_name: 'Администратор', editable: false, permissions },
    { role: 'MEMBER', display_name: 'Пользователь', editable: true, permissions },
  ] }
  const sampledAt = new Date().toISOString()
  const readiness = {
    status: 'degraded', checked_at: sampledAt,
    database: { status: 'ready', sampled_at: sampledAt, pending_revocations: 0,
      available_bytes: null, total_bytes: null, reserved_bytes: null, protected_bytes: null, headroom_bytes: null },
    sfu: { status: 'unknown', reason: 'not_configured', sampled_at: sampledAt, pending_revocations: null,
      available_bytes: null, total_bytes: null, reserved_bytes: null, protected_bytes: null, headroom_bytes: null },
    storage: { status: 'unknown', reason: 'not_configured', sampled_at: sampledAt, pending_revocations: null,
      available_bytes: null, total_bytes: null, reserved_bytes: null, protected_bytes: null, headroom_bytes: null },
  }

  await page.route('**/api/v1/admin/**', async (route) => {
    const request = route.request()
    const method = request.method()
    const path = new URL(request.url()).pathname.replace('/api/v1', '')
    if (method === 'PATCH' && path.startsWith('/admin/accounts/')) {
      patchRequests++
      if (holdNextPatch) {
        holdNextPatch = false
        beginHeldPatch()
        await new Promise<void>(resolve => { releasePatch = resolve })
      }
    }
    const status = fault === 409 && method === 'GET' ? 200 : fault
    const body = status === 200
      ? path === '/admin/accounts' ? { accounts: [{ ...account, role: memberRole }] }
        : path === '/admin/roles' ? roles
          : path === '/admin/guild-settings' ? { name: 'Автономная гильдия', revision: 1, welcome_channel_id: null }
            : path === '/admin/audit' ? { events: [] }
              : path === '/admin/screen-metrics' ? { samples: [] }
                : path === '/admin/readiness' ? readiness
                : path === '/admin/categories' ? { id: 'category-2', name: 'Новый раздел', position: 1, revision: 2 }
                    : {}
      : { error: { code: `FIXTURE_${status}`, message: `Fixture HTTP ${status}` } }
    if (method === 'PATCH' && path.startsWith('/admin/accounts/') && status === 200) {
      memberRole = request.postDataJSON().role
    }
    await route.fulfill({ status, contentType: 'application/json', body: JSON.stringify(body) })
  })

  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: AdminPanel } = await load('/src/admin/panel/AdminPanel.vue')
    const categories = [{ id: 'category-1', name: 'General', position: 0, channels: [{
      id: 'channel-1', name: 'Text', kind: 'TEXT', position: 0, admission_closed: false,
      admissionClosed: false, unreadCount: 0, mentionCount: 0,
    }] }]
    document.body.innerHTML = '<div id="mount"></div>'
    const section = ref('members')
    const app = createApp({ render: () => h(AdminPanel, {
      accountId: '11111111-1111-4111-8111-111111111111', categories, revision: 1,
      section: section.value, 'onUpdate:section': (next: string) => { section.value = next },
    }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const tab = (name: string) => page.getByRole('navigation', { name: 'Разделы администрирования' }).getByRole('button', { name, exact: true })
  await expect(page.getByRole('heading', { name: /Участники/ })).toBeVisible()
  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  const memberRefresh = page.locator('.admin-directory').getByRole('button', { name: 'Обновить' })
  for (const width of [320, 390]) {
    await page.setViewportSize({ width, height: 844 })
    await expect(memberRefresh).toBeVisible()
    const refreshBounds = await memberRefresh.boundingBox()
    expect(refreshBounds).not.toBeNull()
    expect(refreshBounds!.x).toBeGreaterThanOrEqual(0)
    expect(refreshBounds!.x + refreshBounds!.width).toBeLessThanOrEqual(width)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  }
  await page.setViewportSize({ width: 390, height: 844 })
  await tab('Роли').click()
  await expect(page.getByRole('heading', { name: 'Роли и разрешения' })).toBeVisible()
  await tab('Каналы').click()
  await expect(page.getByRole('heading', { name: 'Управление каналами' })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Выбрать текстовый канал Text' })).toBeVisible()
  await tab('Аудит').click()
  await expect(page.getByText('Показано: 0 из 0 загруженных', { exact: true })).toBeVisible()
  await tab('Медиа').click()
  await expect(page.locator('.admin-media-freshness')).toContainText('Нет данных')
  await expect(page.locator('.admin-media-explain')).toContainText('Отсутствие отчётов не доказывает')
  await tab('Готовность').click()
  await expect(page.locator('.admin-readiness')).toContainText('Есть проблемы готовности')
  await expect(page.locator('.readiness-probe--unknown')).toHaveCount(2)
  await tab('Гильдия').click()
  await expect(page.getByLabel('Название гильдии', { exact: true })).toHaveValue('Автономная гильдия')

  fault = 503
  await page.getByLabel('Название гильдии', { exact: true }).fill('Черновик гильдии')
  await page.locator('.guild-settings').getByRole('button', { name: 'Сохранить' }).click()
  await expect(page.locator('.guild-settings').getByRole('alert')).toContainText('503')
  await expect(page.getByLabel('Название гильдии', { exact: true })).toHaveValue('Черновик гильдии')

  await tab('Участники').click()
  await memberRefresh.click()
  await expect(page.locator('.admin-directory').getByRole('alert')).toContainText('Fixture HTTP 503')
  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  const memberCard = page.locator('.admin-mobile-card').first()
  await memberCard.locator('summary').click()
  const memberRoleDraft = memberCard.getByLabel('Роль: member')
  await memberRoleDraft.selectOption('ADMINISTRATOR')
  holdNextPatch = true
  await memberCard.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await heldPatchStarted
  await expect(page.locator('.admin-directory').locator('.admin-status')).toHaveText('Сохраняем изменения участника…')
  releasePatch()
  await expect(page.locator('.admin-directory').getByRole('alert')).toContainText('Fixture HTTP 503')
  await expect(memberRoleDraft).toHaveValue('ADMINISTRATOR')
  fault = 200
  await memberCard.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(page.locator('.admin-directory').locator('.admin-status')).toHaveText('Права аккаунта member сохранены.')
  await expect(memberRoleDraft).toHaveValue('ADMINISTRATOR')
  fault = 503

  await tab('Роли').click()
  await page.locator('.role-permissions').getByRole('button', { name: 'Обновить' }).click()
  await expect(page.locator('.role-permissions').getByRole('alert')).toContainText('Fixture HTTP 503')
  await tab('Каналы').click()
  await page.locator('input[name="category-name"]').fill('Черновик раздела')
  await page.locator('.admin-category-controls').getByRole('button', { name: 'Создать раздел' }).click()
  await expect(page.locator('.admin-category-controls').getByRole('alert')).toContainText('Fixture HTTP 503')
  await expect(page.locator('input[name="category-name"]')).toHaveValue('Черновик раздела')
  await tab('Аудит').click()
  await page.locator('.admin-audit').getByRole('button', { name: 'Обновить' }).click()
  await expect(page.locator('.admin-audit').getByRole('alert')).toHaveText('Сервис временно не отвечает. Попробуйте позже.')
  await tab('Медиа').click()
  await page.locator('.admin-media-diagnostics').getByRole('button', { name: 'Обновить' }).click()
  await expect(page.locator('.admin-media-diagnostics').getByRole('alert')).toContainText('временно не отвечает')
  await expect(page.locator('.admin-media-freshness')).toContainText('Ошибка обновления')
  await tab('Готовность').click()
  await page.locator('.admin-readiness').getByRole('button', { name: 'Обновить проверку' }).click()
  await expect(page.locator('.admin-readiness').getByRole('alert')).toContainText('временно не отвечает')
  await expect(page.locator('.admin-readiness')).toContainText('Нет свежего подтверждения готовности')

  fault = 403
  await tab('Гильдия').click()
  await page.locator('.guild-settings').getByRole('button', { name: 'Сохранить' }).click()
  await expect(page.locator('.guild-settings').getByRole('alert')).toContainText('403')
  await tab('Участники').click()
  await memberRefresh.click()
  await expect(page.locator('.admin-directory').getByRole('alert')).toHaveText('Нет доступа к этому действию.')
  if (!(await memberCard.evaluate(card => (card as HTMLDetailsElement).open))) await memberCard.locator('summary').click()
  await memberRoleDraft.selectOption('MEMBER')
  await memberCard.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(page.locator('.admin-directory').getByRole('alert')).toHaveText('Нет доступа к этому действию.')
  await expect(memberRoleDraft).toHaveValue('MEMBER')
  await expect(memberCard.getByRole('button', { name: 'Сохранить', exact: true })).toBeDisabled()
  expect(patchRequests).toBe(3)
  fault = 200
  await memberRefresh.click()
  await expect(page.locator('.admin-directory').getByRole('alert')).toHaveCount(0)
  await expect(memberRoleDraft).toHaveValue('MEMBER')
  await expect(memberCard.getByRole('button', { name: 'Сохранить', exact: true })).toBeEnabled()
  expect(patchRequests).toBe(3)
  fault = 403
  await tab('Роли').click()
  await page.locator('.role-permissions').getByRole('button', { name: 'Обновить' }).click()
  await expect(page.locator('.role-permissions').getByRole('alert')).toHaveText('Нет доступа к изменению разрешений этой роли.')
  await tab('Каналы').click()
  await page.locator('input[name="category-name"]').fill('Запрещённый раздел')
  await page.locator('.admin-category-controls').getByRole('button', { name: 'Создать раздел' }).click()
  await expect(page.locator('.admin-category-controls').getByRole('alert')).toContainText('Fixture HTTP 403')
  await tab('Аудит').click()
  await page.locator('.admin-audit').getByRole('button', { name: 'Обновить' }).click()
  await expect(page.locator('.admin-audit').getByRole('alert')).toHaveText('Нет доступа к этому действию.')
  await tab('Медиа').click()
  await expect(page.locator('.admin-media-diagnostics').getByRole('alert')).toContainText('Нет доступа')
  await expect(page.locator('.admin-media-diagnostics').getByRole('button', { name: 'Обновление недоступно' })).toBeDisabled()
  await tab('Готовность').click()
  await expect(page.locator('.admin-readiness').getByRole('alert')).toContainText('Нет доступа')
  await expect(page.locator('.admin-readiness').getByRole('button', { name: 'Обновление недоступно' })).toBeDisabled()

  fault = 409
  await tab('Участники').click()
  if (!(await memberCard.evaluate(card => (card as HTMLDetailsElement).open))) await memberCard.locator('summary').click()
  await memberCard.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(page.locator('.admin-directory').getByRole('alert')).toContainText('Fixture HTTP 409')
  await expect(memberRoleDraft).toHaveValue('MEMBER')
  expect(patchRequests).toBe(4)
  await tab('Гильдия').click()
  await page.getByLabel('Название гильдии', { exact: true }).fill('Черновик после конфликта')
  await page.locator('.guild-settings').getByRole('button', { name: 'Сохранить' }).click()
  await expect(page.locator('.guild-settings').getByRole('alert')).toContainText('изменил другой администратор')
  await expect(page.getByLabel('Название гильдии', { exact: true })).toHaveValue('Черновик после конфликта')
  await tab('Каналы').click()
  await page.locator('input[name="category-name"]').fill('Раздел после конфликта')
  await page.locator('.admin-category-controls').getByRole('button', { name: 'Создать раздел' }).click()
  await expect(page.locator('.admin-category-controls').getByRole('alert')).toContainText('Fixture HTTP 409')
  await expect(page.locator('input[name="category-name"]')).toHaveValue('Раздел после конфликта')
})
