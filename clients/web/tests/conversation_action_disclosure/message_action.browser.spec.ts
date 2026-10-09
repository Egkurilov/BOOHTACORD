import { mkdir } from 'node:fs/promises'
import { join } from 'node:path'
import { expect, test } from '@playwright/test'
import { expectAxeClear } from '../accessibility/axe'

test('R02 keeps only the touched message action disclosure open', async ({ page }) => {
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: MessageItem } = await load('/src/conversation/MessageItem.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const messages = [1, 2, 3].map((index) => ({
      id: `message-${index}`,
      channelId: 'channel-1',
      authorId: `user-${index}`,
      clientMessageId: `client-${index}`,
      body: `Сообщение ${index}`,
      createdAt: '2026-10-04T12:00:00Z',
      revision: 1,
      deleted: false,
    }))
    const app = createApp({ render: () => h('div', [
      h('div', { class: 'message-list' }, messages.map((message) =>
        h(MessageItem, { message, canEdit: false, canDelete: false,
          onReply: () => { document.body.dataset.replies = String(Number(document.body.dataset.replies ?? '0') + 1) },
        }))),
      h('button', { id: 'outside' }, 'Вне списка'),
    ]) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const rows = page.locator('.message-row')
  const firstToggle = rows.nth(0).locator('.message-actions-toggle')
  await expect(page.locator('.message-actions.is-open')).toHaveCount(0)
  await expect(firstToggle).toHaveCSS('opacity', '1')
  expect((await firstToggle.boundingBox())?.height).toBeGreaterThanOrEqual(44)
  await rows.nth(0).getByText('Сообщение 1').tap()
  await expect(rows.nth(0).locator('.message-actions')).not.toHaveClass(/is-open/)

  const firstBounds = await rows.nth(0).boundingBox()
  await rows.nth(0).dispatchEvent('pointerdown', {
    pointerType: 'touch', pointerId: 101, isPrimary: true, button: 0,
    clientX: (firstBounds?.x ?? 20) + 80, clientY: (firstBounds?.y ?? 20) + 12,
  })
  await page.waitForTimeout(80)
  await rows.nth(0).dispatchEvent('pointermove', {
    pointerType: 'touch', pointerId: 101, isPrimary: true, button: 0,
    clientX: (firstBounds?.x ?? 20) + 82, clientY: (firstBounds?.y ?? 20) + 42,
  })
  await page.waitForTimeout(550)
  await rows.nth(0).dispatchEvent('pointerup', { pointerType: 'touch', pointerId: 101, isPrimary: true, button: 0 })
  await expect(rows.nth(0).locator('.message-actions')).not.toHaveClass(/is-open/)

  await rows.nth(0).dispatchEvent('pointerdown', {
    pointerType: 'touch', pointerId: 102, isPrimary: true, button: 0,
    clientX: (firstBounds?.x ?? 20) + 80, clientY: (firstBounds?.y ?? 20) + 12,
  })
  await page.waitForTimeout(550)
  await rows.nth(0).dispatchEvent('pointerup', { pointerType: 'touch', pointerId: 102, isPrimary: true, button: 0 })
  await expect(rows.nth(0).locator('.message-actions')).toHaveClass(/is-open/)
  expect((await rows.nth(0).getByRole('button', { name: 'Ответить' }).boundingBox())?.height).toBeGreaterThanOrEqual(44)
  await rows.nth(1).locator('.message-actions-toggle').tap()
  await expect(rows.nth(0).locator('.message-actions')).not.toHaveClass(/is-open/)
  await expect(rows.nth(1).locator('.message-actions')).toHaveClass(/is-open/)
  const captureDir = process.env.BOOHTACORD_VISUAL_CAPTURE_DIR
  if (captureDir) {
    await mkdir(captureDir, { recursive: true })
    await page.locator('.message-list').screenshot({ path: join(captureDir, 'message-actions-open-actual.png') })
  }
  await rows.nth(1).getByRole('button', { name: 'Ответить' }).tap()
  await expect(page.locator('body')).toHaveAttribute('data-replies', '1')
  await expect(rows.nth(1).locator('.message-actions-toggle')).toBeFocused()
  await rows.nth(2).locator('.message-actions-toggle').tap()
  await page.locator('#outside').tap()
  await expect(page.locator('.message-actions.is-open')).toHaveCount(0)
  if (captureDir) await page.locator('.message-list').screenshot({ path: join(captureDir, 'message-actions-closed-actual.png') })
})

test('R02 preserves touch actions and passes WCAG axe scan for grouped, system, deleted and failed messages', async ({ page }) => {
  await page.goto('/')
  await page.evaluate(async () => {
    const load = (path: string) => import(path)
    const { createApp, h } = await load('/node_modules/.vite/deps/vue.js')
    const { createPinia } = await load('/node_modules/.vite/deps/pinia.js')
    const { default: MessageItem } = await load('/src/conversation/MessageItem.vue')
    document.body.innerHTML = '<div id="mount"></div>'
    const base = {
      authorId: 'user-1',
      clientMessageId: 'client-1',
      body: 'Сообщение для проверки',
      createdAt: '2026-10-04T12:00:00Z',
      revision: 1,
      deleted: false,
    }
    const messages = [
      { ...base, id: 'grouped', channelId: 'channel-1' },
      { ...base, id: 'system', kind: 'SYSTEM_WELCOME' },
      { ...base, id: 'deleted', channelId: 'channel-1', deleted: true },
      { ...base, id: 'failed', channelId: 'channel-1', sendStatus: 'failed', retryBlocked: false },
    ]
    const app = createApp({ render: () => h('div', { class: 'message-list' }, messages.map((message, index) =>
      h(MessageItem, { message, grouped: index === 0, canEdit: false, canDelete: index === 1,
        retryDisabled: false,
        onReply: () => {}, onRetry: () => {}, onRemove: () => {},
      }))) })
    app.use(createPinia())
    app.mount('#mount')
  })

  const rows = page.locator('.message-row')
  const grouped = rows.filter({ has: page.getByText('Сообщение для проверки') }).first()
  const groupedButton = grouped.locator('.message-actions-toggle')
  await expect(groupedButton).toBeVisible()
  expect((await groupedButton.boundingBox())?.height).toBeGreaterThanOrEqual(44)

  const systemDelete = page.getByRole('button', { name: 'Удалить системное приветствие' })
  await expect(systemDelete).toBeVisible()
  expect((await systemDelete.boundingBox())?.height).toBeGreaterThanOrEqual(44)

  const deleted = rows.filter({ hasText: 'Сообщение удалено' })
  await expect(deleted.locator('.message-actions-toggle')).toHaveCount(0)

  const failed = rows.filter({ hasText: 'Не отправлено' })
  const retry = failed.getByRole('button', { name: 'Повторить отправку' })
  await expect(retry).toBeVisible()
  await expect(failed.locator('.message-actions-toggle')).toHaveCount(0)
  expect((await retry.boundingBox())?.height).toBeGreaterThanOrEqual(44)

  await expectAxeClear(page, '.message-list')
})
