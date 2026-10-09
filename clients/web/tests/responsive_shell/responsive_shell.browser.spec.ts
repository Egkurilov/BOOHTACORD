import { expect, test } from '@playwright/test'
import { ux2026ReferenceViewports, ux2026RequiredViewports, ux2026ShellViewports } from '../uiux_2026/viewport_matrix'

const viewports = ux2026ShellViewports
const screenshotViewports = new Set([...ux2026RequiredViewports, ...ux2026ReferenceViewports].map(({ width, height }) => `${width}x${height}`))

test('production shell CSS stays within the viewport and preserves its workspace while resizing', async ({ page }, testInfo) => {
  await page.setViewportSize(viewports[2])
  await page.goto('/tests/responsive_shell/fixture.html')

  for (const viewport of viewports) {
    await page.setViewportSize(viewport)
    const main = await page.getByTestId('workspace-main').boundingBox()
    const shell = await page.getByTestId('workspace-shell').boundingBox()
    const composer = await page.getByTestId('composer-wrap').boundingBox()

    expect(shell?.width).toBe(viewport.width)
    expect(main?.x).toBe(viewport.width < 1024 ? 0 : 280)
    expect(main?.width).toBe(viewport.width < 1024 ? viewport.width : viewport.width < 1280 ? viewport.width - 280 : viewport.width - 528)
    expect(composer?.x).toBeGreaterThanOrEqual(0)
    expect((composer?.x ?? 0) + (composer?.width ?? 0)).toBeLessThanOrEqual(viewport.width)
    expect((composer?.y ?? 0) + (composer?.height ?? 0)).toBeLessThanOrEqual(viewport.height)
    expect(await page.getByTestId('workspace-main').getAttribute('data-channel-id')).toBe('general')
    await expect(page.getByTestId('message-list').getByText(/Состояние беседы сохраняется/)).toBeVisible()
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true)

    const dock = page.getByTestId('mobile-voice-dock')
    await expect(dock).toBeVisible()
    const dockBox = await dock.boundingBox()
    if (viewport.width < 1024) {
      expect(dockBox?.y).toBeGreaterThanOrEqual(viewport.height - 53)
      expect((dockBox?.y ?? 0) + (dockBox?.height ?? 0)).toBeLessThanOrEqual(viewport.height)
    } else {
      const sidebar = await page.getByTestId('workspace-sidebar').boundingBox()
      expect(dockBox?.x).toBeGreaterThanOrEqual(sidebar?.x ?? 0)
      expect((dockBox?.x ?? 0) + (dockBox?.width ?? 0)).toBeLessThanOrEqual((sidebar?.x ?? 0) + (sidebar?.width ?? 0))
    }
    if (screenshotViewports.has(`${viewport.width}x${viewport.height}`)) {
      await page.screenshot({ path: testInfo.outputPath(`shell-${viewport.width}x${viewport.height}.png`), fullPage: true })
    }
  }
})

test('the mobile navigation drawer opens inside its available width', async ({ page }) => {
  for (const width of [320, 390, 600, 840]) {
    await page.setViewportSize({ width, height: 844 })
    await page.goto('/tests/responsive_shell/fixture.html')
    await page.getByRole('button', { name: 'Открыть навигацию' }).click()
    const drawer = await page.getByTestId('workspace-drawer').boundingBox()
    expect(drawer?.width).toBe(Math.min(320, width - 40))
    expect(drawer?.x).toBe(0)
    if (width <= 720) {
      await page.getByTestId('workspace-drawer').getByRole('button', { name: 'Закрыть навигацию' }).click()
    } else {
      await page.locator('.drawer-scrim').click({ position: { x: width - 8, y: 400 } })
    }
    await expect(page.getByTestId('workspace-drawer')).toBeHidden()
  }
})

test('browser Back and Forward close and restore overlays without losing workspace or voice state', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/responsive_shell/fixture.html')
  const initialUrl = page.url()
  const drawer = page.getByTestId('workspace-drawer')
  const search = page.getByTestId('search-drawer')

  await page.getByRole('button', { name: 'Открыть навигацию' }).click()
  await expect(drawer).toBeVisible()
  await page.reload()
  await expect(drawer).toBeVisible()
  await page.goBack()
  await expect(drawer).toBeHidden()
  await expect(page.getByText('Голос подключён')).toBeVisible()
  expect(await page.getByTestId('workspace-main').getAttribute('data-channel-id')).toBe('general')
  expect(page.url()).toBe(initialUrl)

  await page.goForward()
  await expect(drawer).toBeVisible()
  await page.getByTestId('workspace-drawer').getByRole('button', { name: 'Закрыть навигацию' }).click()
  await expect(drawer).toBeHidden()
  await page.getByRole('button', { name: 'Открыть поиск' }).click()
  await expect(page.locator('#app')).toHaveAttribute('data-drawer-state', 'search')
  await expect(search).toBeVisible()
  await page.goBack()
  await expect(search).toBeHidden()
  await page.goForward()
  await expect(search).toBeVisible()

  await page.getByRole('button', { name: 'Закрыть поиск' }).click()
  await expect(search).toBeHidden()
  await page.getByRole('button', { name: 'Открыть навигацию' }).click()
  await page.getByRole('button', { name: 'Выбрать канал' }).click()
  await expect(drawer).toBeHidden()
  expect(await page.getByTestId('workspace-main').getAttribute('data-channel-id')).toBe('announcements')
  await page.goBack()
  await expect(drawer).toBeHidden()
  await expect(search).toBeHidden()

  const admin = page.getByTestId('admin-panel')
  await page.getByRole('button', { name: 'Открыть администрирование' }).click()
  await expect(admin).toBeVisible()
  await page.goBack()
  await expect(admin).toBeHidden()
  expect(await page.getByTestId('workspace-main').getAttribute('data-channel-id')).toBe('announcements')
  await page.goForward()
  await expect(admin).toBeVisible()
  await page.getByRole('button', { name: 'Закрыть администрирование' }).click()
  await expect(admin).toBeHidden()
})

test('the production drawer focus manager traps focus and restores it after Escape and selection', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 })
  await page.goto('/tests/responsive_shell/focus_fixture.html')
  const trigger = page.getByRole('button', { name: 'Открыть навигацию' })
  const selection = page.getByRole('button', { name: 'Выбрать канал' })

  await trigger.click()
  await expect(page.getByRole('dialog', { name: 'Навигация по каналам' })).toHaveAttribute('aria-modal', 'true')
  await expect(selection).toBeFocused()
  await page.keyboard.press('Tab')
  await expect(selection).toBeFocused()
  await page.keyboard.press('Escape')
  await expect(trigger).toBeFocused()
  await expect(page.getByRole('dialog')).toHaveCount(0)

  await trigger.click()
  await expect(selection).toBeFocused()
  await selection.click()
  await expect(trigger).toBeFocused()
  await expect(page.getByRole('dialog')).toHaveCount(0)
  await expect(page.getByText('Канал: общий')).toBeVisible()
})
