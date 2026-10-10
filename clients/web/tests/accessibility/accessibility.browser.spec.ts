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
  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  const memberSearch = page.getByRole('searchbox', { name: 'Поиск участников' })
  await memberSearch.fill('без совпадений')
  await expect(page.getByText('Показано: 0 из 1 загруженных', { exact: true })).toBeVisible()
  await expect(page.getByText('По текущим фильтрам участников нет.')).toBeVisible()
  await page.getByRole('button', { name: 'Сбросить фильтры' }).click()
  await expect(memberSearch).toHaveValue('')
  await expect(page.locator('.admin-mobile-card summary strong')).toHaveText('Участник')
  const statusFilter = page.getByRole('combobox', { name: 'Фильтр по статусу' })
  await statusFilter.selectOption('BLOCKED')
  await expect(page.getByText('Показано: 0 из 1 загруженных', { exact: true })).toBeVisible()
  await expect(page.getByText('По текущим фильтрам участников нет.')).toBeVisible()
  await page.getByRole('button', { name: 'Сбросить фильтры' }).click()
  await expect(statusFilter).toHaveValue('ALL')
  for (const width of [320, 390]) {
    await page.setViewportSize({ width, height: 844 })
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    for (const select of await page.locator('.admin-member-filters select').all()) {
      const bounds = await select.boundingBox()
      expect(bounds).not.toBeNull()
      expect((bounds?.x ?? 0) + (bounds?.width ?? 0)).toBeLessThanOrEqual(width)
    }
  }
  await page.setViewportSize({ width: 390, height: 844 })
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

test('browser text scaling to 200 percent reflows channel, admin, and settings controls', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })

  const expectRootScaledText = async (selector: string) => {
    const target = page.locator(selector).first()
    await page.evaluate(() => { document.documentElement.style.fontSize = '100%' })
    const baseline = Number.parseFloat(await target.evaluate(element => getComputedStyle(element).fontSize))
    await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })
    const scaled = Number.parseFloat(await target.evaluate(element => getComputedStyle(element).fontSize))
    expect(scaled, `${selector} follows 200% browser text sizing`).toBeCloseTo(baseline * 2, 1)
  }
  const expectNoDocumentOverflow = async () => {
    const dimensions = await page.evaluate(() => ({
      scrollWidth: document.documentElement.scrollWidth,
      viewportWidth: window.innerWidth,
      overflowing: [...document.querySelectorAll<HTMLElement>('*')]
        .filter(element => element.getBoundingClientRect().right > window.innerWidth + 1)
        .map(element => {
          const rect = element.getBoundingClientRect()
          return `${element.tagName.toLowerCase()}.${element.className.toString()}(${rect.left}-${rect.right}; parent=${element.parentElement?.getBoundingClientRect().left}-${element.parentElement?.getBoundingClientRect().right})`
        }),
    }))
    expect(dimensions.scrollWidth, JSON.stringify(dimensions)).toBeLessThanOrEqual(dimensions.viewportWidth)
  }

  await mountProductionComponent(page, '/src/identity/ProfileSettings.vue', {
    profile: { account_id: '11111111-1111-4111-8111-111111111111', login: 'member', display_name: 'Участник', role: 'MEMBER' },
    loading: false,
    loadError: null,
  }, 'workspace-main-panel workspace-main-panel--profile')
  await expectRootScaledText('#profile-settings-title')
  for (const width of [320, 390, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    await expectNoDocumentOverflow()
    await expect(page.getByRole('button', { name: 'Сохранить профиль' })).toBeVisible()
  }

  await page.route('**/api/v1/admin/accounts?*', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ accounts: [{ account_id: '11111111-1111-4111-8111-111111111111', login: 'member', display_name: 'Участник', role: 'MEMBER', blocked: false, created_at: '2026-10-01T12:00:00Z', updated_at: '2026-10-01T12:00:00Z' }] }),
  }))
  await mountProductionComponent(page, '/src/admin/panel/AdminPanel.vue', { categories: [], revision: 1 }, 'workspace-main-panel workspace-main-panel--admin')
  await expectRootScaledText('#admin-panel-title')
  for (const width of [320, 390, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    await expectNoDocumentOverflow()
    await expect(page.getByRole('navigation', { name: 'Разделы администрирования' }).getByRole('button', { name: 'Участники' })).toBeVisible()
    if (width >= 1024) {
      const tabs = page.locator('.admin-section-tabs')
      const tabsBounds = await tabs.boundingBox()
      expect(tabsBounds).not.toBeNull()
      for (const tab of await tabs.getByRole('button').all()) {
        const bounds = await tab.boundingBox()
        expect(bounds).not.toBeNull()
        expect(bounds?.x ?? 0).toBeGreaterThanOrEqual(tabsBounds?.x ?? 0)
        expect((bounds?.x ?? 0) + (bounds?.width ?? 0)).toBeLessThanOrEqual((tabsBounds?.x ?? 0) + (tabsBounds?.width ?? 0))
      }
    }
  }

  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: MessageItem } = await load('/src/conversation/MessageItem.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const message = { id: 'scale-message', channelId: 'channel-1', authorId: 'user-1', clientMessageId: 'scale-client', body: 'Длинная строка сообщения проверяет перенос текста и доступность действий при увеличении системного размера шрифта.', createdAt: '2026-10-04T12:00:00Z', revision: 1, deleted: false }
    const app = createApp({ render: () => h('div', { class: 'message-list' }, [h(MessageItem, { message, canEdit: false, canDelete: false })]) })
    app.use(createPinia())
    app.mount('#mount')
  })
  await expectRootScaledText('.message-item p')
  for (const width of [320, 390, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    await expectNoDocumentOverflow()
    if (width <= 600) {
      await expect(page.getByRole('button', { name: 'Действия с сообщением' })).toBeVisible()
      const message = await page.locator('.message-item p').first().boundingBox()
      const actions = await page.getByRole('button', { name: 'Действия с сообщением' }).boundingBox()
      expect(message).not.toBeNull()
      expect(actions).not.toBeNull()
      expect((message?.x ?? 0) + (message?.width ?? 0)).toBeLessThanOrEqual(actions?.x ?? 0)
    } else {
      await page.locator('.message-item').hover()
      await expect(page.getByRole('button', { name: 'Ответить' })).toBeVisible()
    }
  }

  await mountProductionComponent(page, '/src/shared/workspace_header/SettingsWorkspaceHeader.vue', {
    panel: 'admin',
    navExpanded: false,
  })
  await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })
  const adminTitleFull = page.locator('.settings-workspace-title-full')
  const adminTitleCompact = page.locator('.settings-workspace-title-compact')
  await expect(adminTitleFull).toHaveText('Администрирование')
  for (const width of [320, 390, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    const adminTitle = width <= 1023 ? adminTitleCompact : adminTitleFull
    await expect(adminTitle).toBeVisible()
    const bounds = await adminTitle.evaluate(element => {
      const text = element as HTMLElement
      const titleRect = text.getBoundingClientRect()
      const headerRect = text.parentElement!.getBoundingClientRect()
      return {
        clientWidth: text.clientWidth,
        scrollWidth: text.scrollWidth,
        titleBottom: titleRect.bottom,
        headerBottom: headerRect.bottom,
      }
    })
    expect(bounds.scrollWidth, JSON.stringify(bounds)).toBeLessThanOrEqual(bounds.clientWidth)
    expect(bounds.titleBottom, JSON.stringify(bounds)).toBeLessThanOrEqual(bounds.headerBottom + 1)
  }
})

test('reduced-motion preference suppresses UI transitions and smooth scrolling', async ({ page }) => {
  await page.goto('/')
  await page.emulateMedia({ reducedMotion: 'reduce' })
  const style = await page.evaluate(() => {
    const button = document.createElement('button')
    button.className = 'gc-button'
    button.textContent = 'Проверка движения'
    document.body.append(button)
    const computed = getComputedStyle(button)
    const result = { transitionDuration: computed.transitionDuration, scrollBehavior: getComputedStyle(document.documentElement).scrollBehavior }
    button.remove()
    return result
  })
  const transitionSeconds = style.transitionDuration.endsWith('ms')
    ? Number.parseFloat(style.transitionDuration) / 1000
    : Number.parseFloat(style.transitionDuration)
  expect(transitionSeconds).toBeLessThanOrEqual(0.0001)
  expect(style.scrollBehavior).toBe('auto')
})

test('profile settings preserve a dirty name across tabs and expose pending and saved states', async ({ page }) => {
  let profileSaveAttempts = 0
  await page.route('**/api/v1/**', route => route.fulfill({
    status: 200, contentType: 'application/json', body: '{}',
  }))
  await page.route('**/api/v1/me', async route => {
    if (route.request().method() !== 'PATCH') {
      return route.fulfill({
        status: 200, contentType: 'application/json',
        body: JSON.stringify({ account_id: 'self', login: 'member', display_name: 'Участник', role: 'MEMBER' }),
      })
    }
    profileSaveAttempts += 1
    await new Promise(resolve => setTimeout(resolve, 600))
    if (profileSaveAttempts === 1) {
      return route.fulfill({
        status: 503, contentType: 'application/json',
        body: JSON.stringify({ error: { message: 'Сервис временно недоступен. Повторите попытку.' } }),
      })
    }
    const body = route.request().postDataJSON() as { display_name: string }
    return route.fulfill({
      status: 200, contentType: 'application/json',
      body: JSON.stringify({ account_id: 'self', login: 'member', display_name: body.display_name, role: 'MEMBER', profile_revision: 2 }),
    })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const [{ createApp, h, ref }, { default: Component }] = await Promise.all([
      import('/node_modules/.vite/deps/vue.js'),
      import('/src/identity/ProfileSettings.vue'),
    ]) as any
    const profile = ref({ account_id: 'self', login: 'member', display_name: 'Участник', role: 'MEMBER' })
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(Component, {
      profile: profile.value, loading: false, loadError: null,
      onSaved: (saved: typeof profile.value) => { profile.value = saved },
    }) }).mount('#mount')
  })

  const name = page.getByRole('textbox', { name: 'Отображаемое имя' })
  await name.fill('Новое имя')
  await expect(page.getByText('Есть несохранённые изменения', { exact: true })).toBeVisible()
  await page.getByRole('tab', { name: 'Безопасность' }).click()
  await page.getByRole('tab', { name: 'Профиль' }).click()
  await expect(name).toHaveValue('Новое имя')

  const save = page.getByRole('button', { name: 'Сохранить профиль' })
  await save.click()
  await expect(page.getByText('Сохраняем имя профиля…', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохраняем…' })).toBeDisabled()
  await expect(page.getByText('Сервис временно недоступен. Повторите попытку.', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохранить профиль' })).toBeEnabled()
  await page.getByRole('button', { name: 'Сохранить профиль' }).click()
  await expect(page.getByText('Сохраняем имя профиля…', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохраняем…' })).toBeDisabled()
  await expect(page.getByText('Имя профиля сохранено.', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохранить профиль' })).toBeDisabled()
  await name.fill('Следующее имя')
  await expect(page.getByText('Есть несохранённые изменения', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Сохранить профиль' })).toBeEnabled()
})

test('profile logout waits for an explicit confirmation', async ({ page }) => {
  await page.route('**/api/v1/**', route => route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }))
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const [{ createApp, h }, { default: Component }] = await Promise.all([
      import('/node_modules/.vite/deps/vue.js'),
      import('/src/identity/ProfileSettings.vue'),
    ]) as any
    const profile = { account_id: 'self', login: 'member', display_name: 'Участник', role: 'MEMBER' }
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(Component, {
      profile, loading: false, loadError: null,
      onLogout: () => { document.body.dataset.logout = 'confirmed' },
    }) }).mount('#mount')
  })

  const name = page.getByRole('textbox', { name: 'Отображаемое имя' })
  await name.fill('Несохранённое имя')
  await page.getByRole('tab', { name: 'Безопасность' }).click()
  await page.getByRole('button', { name: 'Выйти из аккаунта' }).click()
  const discard = page.getByRole('dialog', { name: 'Несохранённые изменения' })
  await expect(discard).toBeVisible()
  await discard.getByRole('button', { name: 'Отмена' }).click()
  await expect(discard).toHaveCount(0)
  expect(await page.locator('body').getAttribute('data-logout')).toBeNull()

  await page.getByRole('button', { name: 'Выйти из аккаунта' }).click()
  await page.getByRole('dialog', { name: 'Несохранённые изменения' }).getByRole('button', { name: 'Выйти без сохранения' }).click()
  const dialog = page.getByRole('dialog', { name: 'Подтвердите выход из аккаунта' })
  await expect(dialog).toBeVisible()
  await dialog.getByRole('button', { name: 'Отмена' }).click()
  await expect(dialog).toHaveCount(0)
  expect(await page.locator('body').getAttribute('data-logout')).toBeNull()

  await page.getByRole('button', { name: 'Выйти из аккаунта' }).click()
  await page.getByRole('dialog', { name: 'Несохранённые изменения' }).getByRole('button', { name: 'Выйти без сохранения' }).click()
  await page.getByRole('dialog', { name: 'Подтвердите выход из аккаунта' }).getByRole('button', { name: 'Выйти' }).click()
  await expect(page.locator('body')).toHaveAttribute('data-logout', 'confirmed')
})

test('empty direct-message navigation offers a visible start-conversation action', async ({ page }) => {
  await page.route('**/api/v1/members?*', route => route.fulfill({
    status: 200, contentType: 'application/json', body: JSON.stringify({ members: [{
      user_id: 'member-1', login: 'alice', display_name: 'Алиса', role: 'MEMBER',
    }] }),
  }))
  await page.route('**/api/v1/auth/session', route => route.fulfill({
    status: 200, contentType: 'application/json',
    body: JSON.stringify({ authenticated: true, account_id: 'self', role: 'MEMBER' }),
  }))
  await page.route('**/api/v1/direct-message-candidates*', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ candidates: [{ id: 'member-1', display_name: 'Алиса' }] }),
  }))
  await page.route('**/api/v1/direct-messages', route => route.fulfill({
    status: 201,
    contentType: 'application/json',
    body: JSON.stringify({
      id: 'dm-1', participant_one_id: 'self', participant_two_id: 'member-1',
      created_at: '2026-10-09T12:00:00Z',
    }),
  }))
  await page.route('**/api/v1/direct-messages/dm-1/messages*', route => route.fulfill({
    status: 200, contentType: 'application/json', body: JSON.stringify({ messages: [] }),
  }))
  await page.setViewportSize({ width: 320, height: 720 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const [{ createApp, h, ref }, { createPinia }, { useDirectMessageStore }, { default: Navigation }, { default: Conversation }] = await Promise.all([
      load('/node_modules/.vite/deps/vue.js'),
      load('/node_modules/.vite/deps/pinia.js'),
      load('/src/direct_message/direct_message_store.ts'),
      load('/src/direct_message/DirectMessageNavigation.vue'),
      load('/src/direct_message/DirectMessageConversation.vue'),
    ]) as any
    const pinia = createPinia()
    const directMessages = useDirectMessageStore(pinia)
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({
      setup() {
        const opened = ref('')
        return () => h('main', [
          h(Navigation, {
            directMessages: [], error: null, loading: false,
            onOpen: (id: string) => { opened.value = id; void directMessages.open(id) },
          }),
          h('output', { 'data-testid': 'opened-direct-message' }, opened.value),
          opened.value ? h(Conversation, {
            accountId: 'self', active: true, directMessageId: opened.value,
            otherParticipantId: 'member-1', otherParticipantDisplayName: 'Алиса', navOpen: false,
          }) : null,
        ])
      },
    }).use(pinia).mount('#mount')
  })

  await expect(page.getByText('Начните личный разговор с участником.', { exact: true })).toBeVisible()
  const start = page.getByRole('button', { name: 'Начать диалог' })
  await expect(start).toBeVisible()
  await expect(start).toContainText('Начать диалог')
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  await expectAxeClear(page, '.direct-message-navigation')
  await start.click()
  await expect(page.getByRole('dialog', { name: 'Новый личный диалог' })).toBeVisible()
  await page.getByRole('button', { name: 'Алиса' }).click()
  await expect(page.getByTestId('opened-direct-message')).toHaveText('dm-1')
  await expect(page.getByRole('heading', { name: 'Алиса' })).toBeVisible()
  await expect(page.getByRole('textbox', { name: 'Сообщение' })).toBeVisible()
  await expect(page.getByText('Сообщений пока нет.')).toBeVisible()
})

test('direct-message search keeps its query and results after opening and returning from context', async ({ page }) => {
  await page.route('**/api/v1/**', route => {
    const url = new URL(route.request().url())
    const message = {
      id: 'message-1', direct_message_id: 'dm-1', author_id: 'member-1',
      client_message_id: 'client-message-1', body: 'Оригинальный контекст',
      created_at: '2026-10-09T12:00:00Z', revision: 1, deleted: false,
      attachments: [], mention_user_ids: [],
    }
    if (url.pathname === '/api/v1/auth/session') {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ authenticated: true, account_id: 'self', role: 'MEMBER' }) })
    }
    if (url.pathname.endsWith('/search')) {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ messages: [{
        id: message.id, direct_message_id: 'dm-1', author_id: 'member-1',
        body: 'Найденный результат', created_at: message.created_at, revision: 1,
      }] }) })
    }
    if (url.pathname.endsWith('/messages')) {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ messages: url.searchParams.has('at') ? [message] : [] }) })
    }
    if (url.pathname === '/api/v1/members') {
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ members: [{
        user_id: 'member-1', login: 'alice', display_name: 'Алиса', role: 'MEMBER',
      }] }) })
    }
    return route.fulfill({ status: 200, contentType: 'application/json', body: '{}' })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const [{ createApp, h, ref }, { createPinia }, { useDirectMessageStore }, { default: Component }] = await Promise.all([
      load('/node_modules/.vite/deps/vue.js'),
      load('/node_modules/.vite/deps/pinia.js'),
      load('/src/direct_message/direct_message_store.ts'),
      load('/src/direct_message/DirectMessageConversation.vue'),
    ]) as any
    const pinia = createPinia()
    const store = useDirectMessageStore(pinia)
    const conversationId = ref('dm-1')
    await store.open(conversationId.value)
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h('main', [
      h('button', {
        type: 'button',
        onClick: () => {
          conversationId.value = conversationId.value === 'dm-1' ? 'dm-2' : 'dm-1'
          void store.open(conversationId.value)
        },
      }, 'Переключить диалог'),
      h(Component, {
        accountId: 'self', active: true, directMessageId: conversationId.value,
        otherParticipantId: 'member-1',
        otherParticipantDisplayName: conversationId.value === 'dm-1' ? 'Алиса' : 'Борис',
        navOpen: false,
      }),
    ]) }).use(pinia).mount('#mount')
  })

  const directSearch = page.getByRole('button', { name: 'Найти сообщение' })
  const openSearch = async () => {
    await expect(directSearch).toBeVisible()
    await directSearch.click()
  }
  await expect(directSearch).toBeVisible()
  const searchBounds = await directSearch.boundingBox()
  expect(searchBounds?.width).toBeGreaterThanOrEqual(44)
  expect(searchBounds?.height).toBeGreaterThanOrEqual(44)
  await openSearch()
  const query = page.getByRole('searchbox', { name: 'Запрос' })
  await query.fill('контекст')
  await page.getByRole('button', { name: 'Найти', exact: true }).click()
  await expect(page.getByText('Найденный результат')).toBeVisible()
  await page.getByRole('button', { name: 'Открыть сообщение' }).click()
  await expect(page.getByRole('heading', { name: 'Контекст найденного сообщения' })).toBeVisible()
  await page.getByRole('button', { name: 'Вернуться к исходной позиции' }).click()
  await expect(page.getByText('Найденный результат')).toBeVisible()

  await page.getByRole('searchbox', { name: 'Запрос' }).press('Escape')
  await expect(page.getByRole('searchbox', { name: 'Запрос' })).toHaveCount(0)
  await page.getByRole('button', { name: 'Переключить диалог' }).click()
  await expect(page.getByRole('heading', { name: 'Борис' })).toBeVisible()
  await openSearch()
  await expect(page.getByRole('searchbox', { name: 'Запрос' })).toHaveValue('')
  await page.getByRole('searchbox', { name: 'Запрос' }).press('Escape')
  await page.getByRole('button', { name: 'Переключить диалог' }).click()
  await expect(page.getByRole('heading', { name: 'Алиса' })).toBeVisible()
  await openSearch()
  await expect(page.getByRole('searchbox', { name: 'Запрос' })).toHaveValue('контекст')
  await expect(page.getByText('Найденный результат')).toBeVisible()
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
  await page.setViewportSize({ width: 320, height: 640 })
  await mountProductionComponent(page, '/src/voice/VoicePrejoin.vue', {
    channelId: 'voice-1', voiceError: null, voiceState: 'DISCONNECTED', voiceTransferRequired: false,
    roster: { channelId: 'voice-1', participants: [], revision: 1 },
  })
  const joinWithMicrophone = page.getByRole('button', { name: 'Подключиться к голосу' })
  const joinAsListener = page.getByRole('button', { name: 'Подключиться без микрофона' })
  await expect(joinWithMicrophone).toBeVisible()
  await expect(joinAsListener).toBeVisible()
  await expect(joinWithMicrophone).toHaveClass(/gc-button--primary/)
  await expect(joinAsListener).toHaveClass(/gc-button--secondary/)
  expect(await page.locator('.voice-prejoin-actions button').evaluateAll((buttons) => buttons.map(button => button.textContent?.trim()))).toEqual([
    'Подключиться к голосу', 'Подключиться без микрофона',
  ])
  await expectAxeClear(page, '.voice-prejoin')
})

test('voice prejoin announces connecting and blocks duplicate joins', async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await mountProductionComponent(page, '/src/voice/VoicePrejoin.vue', {
    channelId: 'voice-1', voiceError: null, voiceState: 'JOINING', voiceTransferRequired: false,
    roster: { channelId: 'voice-1', participants: [], revision: 1 },
  })

  await expect(page.getByRole('heading', { name: 'Подключаемся к голосовой комнате' })).toBeVisible()
  await expect(page.getByText('Соединение устанавливается.')).toBeVisible()
  await expect(page.getByRole('button', { name: 'Подключаемся…' })).toBeDisabled()
  await expect(page.getByRole('button', { name: 'Подключиться без микрофона' })).toBeDisabled()
  await expectAxeClear(page, '.voice-prejoin')
})

test('voice dock explains denied microphone access and exposes a retry at mobile 2x text', async ({ page }, testInfo) => {
  await page.setViewportSize({ width: 320, height: 640 })
  await mountProductionComponent(page, '/src/voice/VoiceDock.vue', {
    channel: { id: 'voice-1', name: 'Комната', kind: 'VOICE', position: 0, admissionClosed: false },
    activeSession: true, error: null, activationMode: 'VAD', deafened: false,
    deafenChanging: false, microphoneMuted: false, microphonePermissionDenied: true,
    state: 'LISTENER', participantCount: 2,
  })
  await page.evaluate(() => { document.documentElement.style.fontSize = '200%' })

  const dock = page.getByTestId('voice-dock')
  const notice = dock.getByRole('status').filter({ hasText: 'Вы подключены как слушатель' })
  const retry = dock.getByRole('button', { name: 'Повторить доступ к микрофону' })
  await expect(notice).toContainText('браузер запретил доступ к микрофону')
  await expect(notice).toContainText('нажмите «Повторить доступ к микрофону»')
  await expect(retry).toBeEnabled()
  await expect(retry).toHaveAttribute('aria-pressed', 'false')
  const bounds = await retry.boundingBox()
  expect(bounds).not.toBeNull()
  expect(bounds!.x).toBeGreaterThanOrEqual(0)
  expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(320)
  expect(bounds!.y + bounds!.height).toBeLessThanOrEqual(640)
  await expectAxeClear(page, '.voice-dock')
  await page.screenshot({ path: testInfo.outputPath('voice-dock-mic-denied-2x.png') })
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
  await expect(page.getByRole('alert')).toHaveText('Сервис временно не отвечает. Попробуйте позже.')
  await expect(status).toHaveText('Нет свежего подтверждения готовности')
  await expect(page.locator('dl dd').first()).toHaveText('устарело')
  await expectAxeClear(page, '#mount')

  await refresh.click()
  await expect(status).toHaveText('Сервисы готовы')
  await expect(page.getByRole('alert')).toHaveCount(0)
})

test('readiness service and capacity values use a responsive dashboard layout', async ({ page }) => {
  const sampledAt = new Date().toISOString()
  await page.route('**/api/v1/**', route => route.fulfill({
    status: 200, contentType: 'application/json', body: '{}',
  }))
  await page.route('**/api/v1/admin/readiness', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({
      status: 'ready', checked_at: sampledAt,
      database: { status: 'ready', reason: null, sampled_at: sampledAt, pending_revocations: 2,
        available_bytes: null, total_bytes: null, reserved_bytes: null, protected_bytes: null, headroom_bytes: null },
      sfu: { status: 'ready', reason: null, sampled_at: sampledAt, pending_revocations: null,
        available_bytes: null, total_bytes: null, reserved_bytes: null, protected_bytes: null, headroom_bytes: null },
      storage: { status: 'ready', reason: null, sampled_at: sampledAt, pending_revocations: null,
        available_bytes: 67108864, total_bytes: 134217728, reserved_bytes: 1048576,
        protected_bytes: 2097152, headroom_bytes: 63963136 },
    }),
  }))
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/panel/AdminPanel.vue', { categories: [], revision: 1, section: 'readiness' }, 'workspace-main-panel workspace-main-panel--admin')

  const section = page.locator('[aria-labelledby="readiness-title"]')
  const tab = page.getByRole('button', { name: 'Готовность', exact: true })
  await expect(tab).toHaveAttribute('aria-current', 'page')
  for (const width of [320, 390, 600, 840, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    await expect(page.getByRole('status').filter({ hasText: 'Сервисы готовы' })).toBeVisible()
    for (const selector of ['.readiness-dependencies', '.readiness-capacity']) {
      const grid = page.locator(selector)
      const bounds = await grid.boundingBox()
      const sectionBounds = await section.boundingBox()
      expect(bounds).not.toBeNull()
      expect(sectionBounds).not.toBeNull()
      expect(bounds!.width).toBeGreaterThan(sectionBounds!.width * 0.9)
      expect(bounds!.x).toBeGreaterThanOrEqual(sectionBounds!.x)
      expect(bounds!.x + bounds!.width).toBeLessThanOrEqual(sectionBounds!.x + sectionBounds!.width + 1)
    }
    for (const pair of await page.locator('.readiness-dependencies > div, .readiness-capacity > div').all()) {
      const bounds = await pair.boundingBox()
      const label = await pair.locator('dt').boundingBox()
      const value = await pair.locator('dd').boundingBox()
      expect(bounds).not.toBeNull()
      expect(label).not.toBeNull()
      expect(value).not.toBeNull()
      expect(label!.x).toBeGreaterThanOrEqual(bounds!.x)
      expect(value!.x + value!.width).toBeLessThanOrEqual(bounds!.x + bounds!.width + 1)
    }
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
  }
})

test('readiness access denial is explained and stops automatic retry', async ({ page }) => {
  await page.clock.install()
  let requests = 0
  await page.route('**/api/v1/admin/readiness', async route => {
    requests += 1
    await route.fulfill({ status: 403, contentType: 'application/json', body: '{}' })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/readiness/Panel.vue')

  await expect(page.getByRole('alert')).toHaveText('Нет доступа к этому разделу.')
  const refresh = page.locator('section[aria-labelledby="readiness-title"] > button')
  await expect(refresh).toBeDisabled()
  await expect(refresh).toHaveText('Обновление недоступно')
  await page.clock.fastForward(5_000)
  expect(requests).toBe(1)
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
  const sampleCard = page.locator('.admin-media-sample').first()
  await expect(sampleCard).toContainText('Воспроизводит')
  const details = sampleCard.locator('details')
  await expect(details).not.toHaveAttribute('open', '')
  await details.locator('summary').click()
  await expect(details).toHaveAttribute('open', '')
  await expectAxeClear(page, '.admin-media-freshness')

  const refresh = page.locator('.admin-media-diagnostics > header > button')
  await refresh.click()
  await expect(refresh).toBeDisabled()
  await expect(refresh).toHaveText('Проверяем…')
  await expect(status).toContainText('Обновляем показатели; предыдущий ответ сохранён')
  releaseRefresh?.()
  await expect(status).toContainText('Ошибка обновления')
  await expect(page.getByRole('alert')).toContainText('Сервис временно не отвечает. Попробуйте позже.')
  await expect(page.getByRole('alert')).toContainText('Прежние измерения нельзя считать текущими')
  await expectAxeClear(page, '.admin-media-freshness')

  await refresh.click()
  await expect(status).toContainText('Есть измерения')
  await expect(page.getByRole('alert')).toHaveCount(0)
})

test('media access denial stops automatic polling and disables retry', async ({ page }) => {
  await page.clock.install()
  let requests = 0
  await page.route('**/api/v1/admin/screen-metrics', async route => {
    requests += 1
    await route.fulfill({ status: 403, contentType: 'application/json', body: '{}' })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/media/AdminMediaDiagnostics.vue')

  const refresh = page.locator('.admin-media-diagnostics > header > button')
  await expect(page.getByRole('alert')).toHaveText('Нет доступа к этому разделу.')
  await expect(refresh).toBeDisabled()
  await page.clock.fastForward(15_000)
  expect(requests).toBe(1)
})

test('media rate limit remains retryable and recovers after a manual retry', async ({ page }) => {
  let requests = 0
  await page.route('**/api/v1/admin/screen-metrics', async route => {
    requests += 1
    if (requests === 1) await route.fulfill({ status: 429, contentType: 'application/json', body: '{}' })
    else await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify({ samples: [] }) })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/media/AdminMediaDiagnostics.vue')

  const refresh = page.locator('.admin-media-diagnostics > header > button')
  await expect(page.getByRole('alert')).toHaveText('Слишком много запросов. Подождите немного и повторите попытку. Повторите обновление.')
  await expect(refresh).toBeEnabled()
  await refresh.click()
  await expect(page.getByRole('status')).toContainText('Нет данных')
  await expect(page.getByRole('alert')).toHaveCount(0)
  expect(requests).toBe(2)
})

test('admin media does not present old measurements as fresh after an empty refresh', async ({ page }) => {
  let requests = 0
  const oldSample = {
    sampled_at_utc: new Date(Date.now() - 120_000).toISOString(),
    report: { platform: 'android_native', direction: 'receiver', state: 'playing', frame_width: 540, frame_height: 1170 },
  }
  await page.route('**/api/v1/admin/screen-metrics', route => {
    requests += 1
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ samples: requests === 1 ? [oldSample] : [] }),
    })
  })
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/media/AdminMediaDiagnostics.vue')

  const status = page.getByRole('status')
  await expect(status).toContainText('Данные устарели')
  await expect(status).toContainText('Свежих отчётов: 0')
  await expect(page.locator('.admin-media-sample')).toHaveCount(0)
  await expect(page.locator('.admin-media-stale')).toContainText('Последнее измерение')

  await page.locator('.admin-media-diagnostics > header > button').click()
  await expect(status).toContainText('Данные устарели')
  await expect(status).toContainText('Свежих отчётов: 0')
  await expect(page.locator('.admin-media-stale')).toContainText('Последнее измерение')
  await expect(page.locator('.admin-media-empty')).toHaveCount(0)
})

test('admin shell exposes all seven sections at 320–1440px and avoids page overflow', async ({ page }) => {
  await page.route('**/api/v1/**', route => route.fulfill({
    status: 200, contentType: 'application/json', body: '{}',
  }))
  await page.setViewportSize({ width: 320, height: 640 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: AdminPanel } = await load('/src/admin/panel/AdminPanel.vue')
    document.body.innerHTML = '<div class="workspace-main-panel--admin" style="display:flex;width:100%;height:100vh;flex-direction:column"><header class="settings-workspace-header"><strong>Администрирование</strong></header><div id="mount"></div></div>'
    const section = ref('members')
    const app = createApp({ render: () => h(AdminPanel, { categories: [], revision: 1, section: section.value, 'onUpdate:section': (next: string) => { section.value = next } }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const panelHeading = page.getByRole('heading', { name: 'Администрирование', exact: true })
  await expect(panelHeading).toBeAttached()
  expect(await panelHeading.evaluate(element => {
    const style = getComputedStyle(element.parentElement!.parentElement!)
    return { position: style.position, width: style.width, overflow: style.overflow, clip: style.clip }
  })).toEqual({ position: 'absolute', width: '1px', overflow: 'hidden', clip: 'rect(0px, 0px, 0px, 0px)' })
  await expect(page.getByRole('heading', { name: /Участники/ })).toBeVisible()

  const nav = page.getByRole('navigation', { name: 'Разделы администрирования' })
  const hint = page.getByText('Прокрутите список разделов по горизонтали', { exact: true })
  await expect(nav.getByRole('button', { name: 'Участники', exact: true })).toBeFocused()
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

  for (const width of [375, 390, 430, 600, 840, 1440]) {
    await page.setViewportSize({ width, height: 844 })
    if (width <= 540) await expect(hint).toBeVisible()
    else await expect(hint).toBeHidden()
    const viewport = await nav.evaluate(element => ({ client: element.clientWidth, scroll: element.scrollWidth }))
    if (width <= 430) expect(viewport.scroll).toBeGreaterThan(viewport.client)
    else expect(viewport.scroll).toBeLessThanOrEqual(viewport.client)
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
    const panelBounds = await page.locator('.admin-panel').boundingBox()
    expect(panelBounds).not.toBeNull()
    expect(panelBounds!.width).toBeLessThanOrEqual(Math.min(width, 880))
    for (const label of labels) {
      const button = nav.getByRole('button', { name: label, exact: true })
      await button.click()
      await expect(button).toHaveAttribute('aria-current', 'page')
      await expect(button).toBeInViewport()
    }
  }
})

test('admin section selection survives closing and reopening its workspace panel', async ({ page }) => {
  await page.route('**/api/v1/**', route => route.fulfill({ status: 200, contentType: 'application/json', body: '{}' }))
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: AdminPanel } = await load('/src/admin/panel/AdminPanel.vue')
    document.body.innerHTML = '<div class="workspace-main-panel--admin" id="mount"></div>'
    const visible = ref(true)
    const section = ref('members')
    Object.assign(window, { __adminPanelState: {
      close: () => { visible.value = false },
      open: () => { visible.value = true },
    } })
    const app = createApp({ render: () => visible.value ? h(AdminPanel, {
      categories: [], revision: 1, section: section.value,
      'onUpdate:section': (next: string) => { section.value = next },
    }) : null })
    app.use(createPinia())
    app.mount('#mount')
  })

  const roles = page.getByRole('button', { name: 'Роли', exact: true })
  await roles.click()
  await expect(roles).toHaveAttribute('aria-current', 'page')
  await page.evaluate(() => (window as Window & { __adminPanelState: { close: () => void } }).__adminPanelState.close())
  await expect(page.getByTestId('admin-panel')).toHaveCount(0)
  await page.evaluate(() => (window as Window & { __adminPanelState: { open: () => void } }).__adminPanelState.open())
  await expect(page.getByRole('button', { name: 'Роли', exact: true })).toHaveAttribute('aria-current', 'page')
})

test('admin member filters survive switching to another admin section', async ({ page }) => {
  await page.route('**/api/v1/admin/accounts?*', route => route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({ accounts: [{
      account_id: '11111111-1111-4111-8111-111111111111', login: 'member', display_name: 'Участник',
      role: 'MEMBER', blocked: false, created_at: '2026-10-01T12:00:00Z', updated_at: '2026-10-01T12:00:00Z',
    }] }),
  }))
  await page.route('**/api/v1/admin/audit?*', route => route.fulfill({
    status: 200, contentType: 'application/json', body: JSON.stringify({ events: [] }),
  }))
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h, ref } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: AdminPanel } = await load('/src/admin/panel/AdminPanel.vue')
    document.body.innerHTML = '<div class="workspace-main-panel--admin" id="mount"></div>'
    const section = ref('members')
    const app = createApp({ render: () => h(AdminPanel, {
      categories: [], revision: 1, section: section.value,
      'onUpdate:section': (next: string) => { section.value = next },
    }) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const search = page.getByRole('searchbox', { name: 'Поиск участников' })
  await search.fill('участник')
  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  await page.getByRole('button', { name: 'Аудит', exact: true }).click()
  await expect(page.getByRole('heading', { name: 'Аудит', exact: true })).toBeVisible()
  await page.getByLabel('Область').selectOption('voice')
  await page.getByRole('button', { name: 'Участники', exact: true }).click()
  await expect(page.getByRole('searchbox', { name: 'Поиск участников' })).toHaveValue('участник')
  await page.getByRole('button', { name: 'Аудит', exact: true }).click()
  await expect(page.getByLabel('Область')).toHaveValue('voice')
})

test('admin audit filters expose result count, empty state and reset', async ({ page }) => {
  await page.route('**/api/v1/admin/audit?*', route => route.fulfill({
    status: 200, contentType: 'application/json', body: JSON.stringify({ events: [{
      id: 'audit-event', event_type: 'CHANNEL_RENAMED', created_at: '2026-10-04T10:00:00Z',
    }] }),
  }))
  await page.setViewportSize({ width: 390, height: 844 })
  await mountProductionComponent(page, '/src/admin/audit/AdminAuditSection.vue', {}, 'workspace-main-panel--admin')

  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  const scope = page.getByLabel('Область')
  await scope.selectOption('voice')
  await expect(page.getByRole('button', { name: 'Сбросить фильтры' })).toBeVisible()
  await expect(page.getByText('Среди загруженных записей совпадений нет.')).toBeVisible()
  await page.getByRole('button', { name: 'Сбросить фильтры' }).click()
  await expect(scope).toHaveValue('all')
  await expect(page.getByText('Показано: 1 из 1 загруженных', { exact: true })).toBeVisible()
  await expect(page.getByText('Система → Канал переименован', { exact: true })).toBeVisible()
  await expectAxeClear(page, '.admin-audit')
})
