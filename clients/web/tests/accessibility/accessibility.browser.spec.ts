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
