import { expect, test } from '@playwright/test'

test('screen-share setup keeps actions visible in a 637x584 desktop viewport', async ({ page }) => {
  await page.setViewportSize({ width: 637, height: 584 })
  await page.goto('/')
  await page.evaluate(async () => {
    const { createApp, h } = await import('/node_modules/.vite/deps/vue.js')
    const { default: ScreenShareSetupDialog } = await import('/src/voice/ScreenShareSetupDialog.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    createApp({ render: () => h(ScreenShareSetupDialog, {
      initialProfile: 'P1080_30', onCancel: () => {}, onStart: () => {},
    }) }).mount('#mount')
  })

  const dialog = page.getByRole('dialog', { name: 'Демонстрация экрана' })
  await expect(dialog).toBeVisible()
  const bounds = await dialog.boundingBox()
  expect(bounds).not.toBeNull()
  expect(bounds!.height).toBeGreaterThan(500)
  expect(bounds!.y).toBeGreaterThanOrEqual(0)
  expect(bounds!.y + bounds!.height).toBeLessThanOrEqual(584)

  const body = dialog.locator('.screen-share-setup__body')
  expect(await body.evaluate(element => element.scrollHeight > element.clientHeight)).toBe(true)
  for (const label of ['Отмена', 'Начать трансляцию']) {
    await expect(dialog.getByRole('button', { name: label })).toBeInViewport({ ratio: 0.99 })
  }
})
