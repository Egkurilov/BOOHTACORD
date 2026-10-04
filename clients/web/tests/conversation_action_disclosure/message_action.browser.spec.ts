import { mkdir } from 'node:fs/promises'
import { join } from 'node:path'
import { expect, test } from '@playwright/test'

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
  await expect(page.locator('.message-actions.is-open')).toHaveCount(0)
  await expect(rows.nth(0).locator('.message-actions-toggle')).toHaveCSS('opacity', '0')
  await rows.nth(0).tap({ position: { x: 70, y: 20 } })
  await expect(rows.nth(0).locator('.message-actions')).toHaveClass(/is-open/)
  await rows.nth(1).tap({ position: { x: 70, y: 20 } })
  await expect(rows.nth(0).locator('.message-actions')).not.toHaveClass(/is-open/)
  await expect(rows.nth(1).locator('.message-actions')).toHaveClass(/is-open/)
  const captureDir = process.env.BOOHTACORD_VISUAL_CAPTURE_DIR
  if (captureDir) {
    await mkdir(captureDir, { recursive: true })
    await page.locator('.message-list').screenshot({ path: join(captureDir, 'message-actions-open-actual.png') })
  }
  await rows.nth(1).getByRole('button', { name: 'Ответить' }).tap()
  await expect(page.locator('body')).toHaveAttribute('data-replies', '1')
  await rows.nth(2).tap({ position: { x: 70, y: 20 } })
  await page.locator('#outside').tap()
  await expect(page.locator('.message-actions.is-open')).toHaveCount(0)
  if (captureDir) await page.locator('.message-list').screenshot({ path: join(captureDir, 'message-actions-closed-actual.png') })
})
