import { expect, test } from '@playwright/test'
import { expectAxeClear } from './axe'

async function mountProductionComponent(
  page: import('@playwright/test').Page,
  component: string,
  props: Record<string, unknown> = {},
  wrapperClass = '',
): Promise<void> {
  await page.goto('/')
  await page.evaluate(async ({ component, props, wrapperClass }) => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { default: Component } = await load(component)
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(wrapperClass ? 'main' : 'div', { class: wrapperClass }, [h(Component, props)]) }).mount('#mount')
  }, { component, props, wrapperClass })
}

test('WCAG smoke covers navigation, search and connected voice dock', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/responsive_shell/fixture.html')

  await expectAxeClear(page, '#app')
  await page.getByRole('button', { name: 'Открыть навигацию' }).click()
  await expectAxeClear(page, '#app')
  await page.getByTestId('workspace-drawer').getByRole('button', { name: 'Закрыть навигацию' }).click()
  await page.getByRole('button', { name: 'Открыть поиск' }).click()
  await expectAxeClear(page, '#app')
})

test('WCAG keyboard smoke covers navigation focus trap and restoration', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/responsive_shell/focus_fixture.html')
  const trigger = page.getByRole('button', { name: 'Открыть навигацию' })
  const selection = page.getByRole('button', { name: 'Выбрать канал' })
  await trigger.click()
  await expect(page.getByRole('dialog', { name: 'Навигация по каналам' })).toBeVisible()
  await expect(selection).toBeFocused()
  await expectAxeClear(page, '.app-frame')
  await page.keyboard.press('Tab')
  await expect(selection).toBeFocused()
  await page.keyboard.press('Escape')
  await expect(trigger).toBeFocused()
})

test('WCAG smoke covers guild admin members on a phone', async ({ page }) => {
  await page.route('**/api/v1/admin/accounts?*', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ accounts: [{
      account_id: '11111111-1111-4111-8111-111111111111',
      login: 'member', display_name: 'Участник', role: 'MEMBER', blocked: false,
      created_at: '2026-10-01T12:00:00Z', updated_at: '2026-10-01T12:00:00Z',
    }] }),
  }))
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/panel/AdminPanel.vue', { categories: [], revision: 1 }, 'workspace-main-panel workspace-main-panel--admin')
  await expect(page.locator('.admin-mobile-card summary strong')).toHaveText('Участник')
  await expectAxeClear(page, '.admin-panel')
})

test('WCAG smoke covers profile settings', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/identity/ProfileSettings.vue', {
    profile: {
      account_id: '11111111-1111-4111-8111-111111111111',
      login: 'member', display_name: 'Участник', role: 'MEMBER',
    },
    loading: false,
    loadError: null,
  }, 'workspace-main-panel workspace-main-panel--profile')
  await expect(page.getByRole('heading', { name: 'Настройки' })).toBeVisible()
  await expectAxeClear(page, '.profile-settings')
})

test('profile settings tabs support Arrow, Home and End keyboard navigation', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/identity/ProfileSettings.vue', {
    profile: {
      account_id: '11111111-1111-4111-8111-111111111111',
      login: 'member', display_name: 'Участник', role: 'MEMBER',
    },
    loading: false,
    loadError: null,
  }, 'workspace-main-panel workspace-main-panel--profile')

  await expect(page.getByRole('heading', { name: 'Настройки' })).toBeFocused()
  const profile = page.getByRole('tab', { name: 'Профиль' })
  const security = page.getByRole('tab', { name: 'Безопасность' })
  const about = page.getByRole('tab', { name: 'О приложении' })
  await profile.focus()
  await page.keyboard.press('ArrowRight')
  await expect(security).toBeFocused()
  await expect(security).toHaveAttribute('aria-selected', 'true')
  await expect(page.getByRole('tabpanel', { name: 'Безопасность' })).toBeVisible()
  await page.keyboard.press('ArrowLeft')
  await expect(profile).toBeFocused()
  await page.keyboard.press('ArrowLeft')
  await expect(about).toBeFocused()
  await expect(about).toHaveAttribute('aria-selected', 'true')
  await page.keyboard.press('Home')
  await expect(profile).toBeFocused()
  await expect(profile).toHaveAttribute('aria-selected', 'true')
  await page.keyboard.press('End')
  await expect(about).toBeFocused()
  await expect(about).toHaveAttribute('aria-selected', 'true')
})

test('WCAG smoke covers voice prejoin actions', async ({ page }) => {
  await mountProductionComponent(page, '/src/voice/VoicePrejoin.vue', {
    channelId: 'voice-1', voiceError: null, voiceState: 'DISCONNECTED', voiceTransferRequired: false,
    roster: { channelId: 'voice-1', participants: [], revision: 1 },
  })
  await expect(page.getByRole('button', { name: 'Подключиться к голосу' })).toBeVisible()
  await expectAxeClear(page, '.voice-prejoin')
})

test('WCAG smoke covers screen share setup and destructive confirmation dialogs', async ({ page }) => {
  await mountProductionComponent(page, '/src/voice/ScreenShareSetupDialog.vue', { initialProfile: 'P1080_30' })
  await expect(page.getByRole('dialog', { name: 'Демонстрация экрана' })).toBeVisible()
  await expectAxeClear(page, '.screen-share-setup-dialog')

  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { default: Confirm } = await load('/src/channel/AdminConfirmation.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const prompt = ref(null)
    createApp({ render: () => h('div', [
      h('button', { onClick: () => void prompt.value.ask('Удалить канал «общее»?') }, 'Удалить канал'),
      h(Confirm, { ref: prompt, id: 'delete-channel', title: 'Удалить канал', confirmLabel: 'Удалить' }),
    ]) }).mount('#mount')
  })
  await page.getByRole('button', { name: 'Удалить канал', exact: true }).click()
  await expect(page.getByRole('dialog', { name: 'Удалить канал' })).toBeVisible()
  await expectAxeClear(page, '.admin-confirm-dialog')
})

test('destructive confirmation defaults to cancel, traps focus and requires an explicit choice', async ({ page }) => {
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { default: Confirm } = await load('/src/channel/AdminConfirmation.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const prompt = ref(null)
    const answer = ref('pending')
    createApp({ render: () => h('div', [
      h('button', {
        onClick: () => void prompt.value.ask('Удалить канал «общее»?').then((confirmed: boolean) => { answer.value = String(confirmed) }),
      }, 'Удалить канал'),
      h('output', { id: 'confirmation-result' }, answer.value),
      h(Confirm, { ref: prompt, id: 'delete-channel', title: 'Удалить канал', confirmLabel: 'Удалить' }),
    ]) }).mount('#mount')
  })

  const trigger = page.getByRole('button', { name: 'Удалить канал', exact: true })
  await trigger.click()
  const dialog = page.getByRole('dialog', { name: 'Удалить канал' })
  const cancel = dialog.getByRole('button', { name: 'Отмена' })
  const confirm = dialog.getByRole('button', { name: 'Удалить', exact: true })
  await expect(cancel).toBeFocused()
  await page.keyboard.press('Enter')
  await expect(dialog).toBeHidden()
  await expect(trigger).toBeFocused()
  await expect(page.locator('#confirmation-result')).toHaveText('false')

  await trigger.click()
  await expect(cancel).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(confirm).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(cancel).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(confirm).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(cancel).toBeFocused()
  await page.mouse.click(1, 1)
  await expect(dialog).toBeVisible()
  await page.keyboard.press('Escape')
  await expect(dialog).toBeHidden()
  await expect(trigger).toBeFocused()
  await expect(page.locator('#confirmation-result')).toHaveText('false')

  await trigger.click()
  await expect(cancel).toBeFocused()
  await confirm.click()
  await expect(dialog).toBeHidden()
  await expect(page.locator('#confirmation-result')).toHaveText('true')
})

test('WCAG smoke distinguishes readiness loading, refresh, stale failure and retry states', async ({ page }) => {
  let requests = 0
  let releaseInitial: (() => void) | undefined
  let releaseRefresh: (() => void) | undefined
  const checkedAt = new Date().toISOString()
  const readyProbe = {
    status: 'ready', sampled_at: checkedAt, pending_revocations: 0,
    available_bytes: 1024, total_bytes: 2048, reserved_bytes: 0,
    protected_bytes: 0, headroom_bytes: 1024,
  }
  const ready = {
    status: 'ready', checked_at: checkedAt,
    database: readyProbe, sfu: readyProbe, storage: readyProbe,
  }
  await page.route('**/api/v1/admin/readiness', async route => {
    requests += 1
    if (requests === 1) {
      await new Promise<void>(resolve => { releaseInitial = resolve })
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(ready) })
    } else if (requests === 2) {
      await new Promise<void>(resolve => { releaseRefresh = resolve })
      await route.fulfill({ status: 503, contentType: 'application/json', body: '{}' })
    } else {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(ready) })
    }
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/readiness/Panel.vue')

  const status = page.getByRole('status')
  await expect(status).toHaveText('Проверяем готовность сервисов')
  releaseInitial?.()
  await expect(status).toHaveText('Сервисы готовы')
  await expectAxeClear(page, '#mount')

  const refresh = page.locator('section[aria-labelledby="readiness-title"] > button')
  await refresh.click()
  await expect(refresh).toBeDisabled()
  await expect(refresh).toHaveText('Проверяем…')
  await expect(status).toHaveText('Обновляем проверку; показан предыдущий результат')
  releaseRefresh?.()
  await expect(page.getByRole('alert')).toHaveText('Сервер не подтвердил готовность.')
  await expect(status).toHaveText('Нет свежего подтверждения готовности')
  await expect(page.locator('dl dd').first()).toHaveText('устарело')
  await expectAxeClear(page, '#mount')

  await refresh.click()
  await expect(status).toHaveText('Сервисы готовы')
  await expect(page.getByRole('alert')).toHaveCount(0)
})

test('screen-share setup keeps keyboard focus inside its modal dialog', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/voice/ScreenShareSetupDialog.vue', { initialProfile: 'P1080_30' })

  const dialog = page.getByRole('dialog', { name: 'Демонстрация экрана' })
  const close = dialog.getByRole('button', { name: 'Закрыть' })
  const start = dialog.getByRole('button', { name: 'Начать трансляцию' })
  await expect(close).toBeFocused()
  await start.focus()
  await page.keyboard.press('Tab')
  await expect(close).toBeFocused()
  await page.keyboard.press('Shift+Tab')
  await expect(start).toBeFocused()
})

test('WCAG smoke distinguishes media metric loading, refresh and failure states', async ({ page }) => {
  let requests = 0
  let releaseInitial: (() => void) | undefined
  let releaseRefresh: (() => void) | undefined
  const sample = {
    sampled_at_utc: new Date().toISOString(),
    report: { platform: 'desktop_web', direction: 'sender', state: 'playing', encoded_fps: 30 },
  }
  await page.route('**/api/v1/admin/screen-metrics', async route => {
    requests += 1
    if (requests === 1) {
      await new Promise<void>(resolve => { releaseInitial = resolve })
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ samples: [sample] }) })
    } else if (requests === 2) {
      await new Promise<void>(resolve => { releaseRefresh = resolve })
      await route.fulfill({ status: 503, contentType: 'application/json', body: '{}' })
    } else {
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ samples: [sample] }) })
    }
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/media/AdminMediaDiagnostics.vue')

  const status = page.getByRole('status')
  await expect(status).toContainText('Загружаем показатели')
  releaseInitial?.()
  await expect(status).toContainText('Есть измерения')
  await expectAxeClear(page, '.admin-media-freshness')

  const refresh = page.locator('.admin-media-diagnostics > header > button')
  await refresh.click()
  await expect(refresh).toBeDisabled()
  await expect(refresh).toHaveText('Проверяем…')
  await expect(status).toContainText('Обновляем показатели; предыдущий ответ сохранён')
  releaseRefresh?.()
  await expect(status).toContainText('Ошибка обновления')
  await expect(page.getByRole('alert')).toContainText('прежние измерения нельзя считать текущими')
  await expectAxeClear(page, '.admin-media-freshness')

  await refresh.click()
  await expect(status).toContainText('Есть измерения')
  await expect(page.getByRole('alert')).toHaveCount(0)
})

test('admin shell exposes all seven sections at 320–430px and avoids page overflow', async ({ page }) => {
  await page.route('**/api/v1/**', route => route.fulfill({
    status: 200, contentType: 'application/json', body: '{}',
  }))
  await page.setViewportSize({ width: 320, height: 640 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: AdminPanel } = await load('/src/admin/panel/AdminPanel.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const app = createApp({ render: () => h(AdminPanel, { categories: [], revision: 1 }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const nav = page.getByRole('navigation', { name: 'Разделы администрирования' })
  const hint = page.getByText('Прокрутите список разделов по горизонтали', { exact: true })
  await expect(hint).toBeVisible()
  const dimensions = await nav.evaluate(element => ({ client: element.clientWidth, scroll: element.scrollWidth }))
  expect(dimensions.scroll).toBeGreaterThan(dimensions.client)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)

  const labels = ['Гильдия', 'Участники', 'Роли', 'Каналы', 'Аудит', 'Медиа', 'Готовность']
  const first = nav.getByRole('button', { name: labels[0], exact: true })
  await first.focus()
  for (const label of labels) {
    const button = nav.getByRole('button', { name: label, exact: true })
    await expect(button).toBeFocused()
    await expect(button).toBeInViewport()
    await page.keyboard.press('Tab')
  }

  for (const label of labels) {
    const button = nav.getByRole('button', { name: label, exact: true })
    await button.click()
    await expect(button).toHaveAttribute('aria-current', 'page')
    await expect(button).toBeInViewport()
  }

  for (const width of [375, 390, 430]) {
    await page.setViewportSize({ width, height: 844 })
    await expect(hint).toBeVisible()
    const viewport = await nav.evaluate(element => ({ client: element.clientWidth, scroll: element.scrollWidth }))
    expect(viewport.scroll).toBeGreaterThan(viewport.client)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  }
})
