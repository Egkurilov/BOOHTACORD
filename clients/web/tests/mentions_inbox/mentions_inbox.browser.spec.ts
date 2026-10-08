import { expect, test } from '@playwright/test'

const textMention = {
  kind: 'CHANNEL', message_id: '22222222-2222-4222-8222-222222222222', conversation_id: '33333333-3333-4333-8333-333333333333',
  author_id: '44444444-4444-4444-8444-444444444444', created_at: '2026-10-08T10:00:00Z',
}
const dmMention = { ...textMention, kind: 'DIRECT_MESSAGE', message_id: '55555555-5555-4555-8555-555555555555' }

test.beforeEach(async ({ page }) => {
  await page.setViewportSize({ width: 1440, height: 1000 })
  await page.route('**/api/v1/mentions*', async (route) => {
    const cursor = new URL(route.request().url()).searchParams.get('before')
    await route.fulfill({ json: cursor ? { mentions: [dmMention] } : { mentions: [textMention], next_cursor: 'cursor-1' } })
  })
  await page.route('**/members/44444444-4444-4444-8444-444444444444', async (route) => {
    await route.fulfill({ json: { user_id: textMention.author_id, login: 'author', display_name: 'Автор', role: 'MEMBER', presence: 'online' } })
  })
  await page.goto('/tests/mentions_inbox/fixture.html')
})

test('renders metadata-only inbox, pages results and emits exact message jump', async ({ page }, testInfo) => {
  await page.getByRole('button', { name: 'Упоминания' }).click()
  await expect(page.getByRole('heading', { name: 'Упоминания' })).toBeVisible()
  await expect(page.getByText('Автор')).toBeVisible()
  await expect(page.getByText(/упомянул\(а\) вас/)).toBeVisible()
  await expect(page.getByText(/private body/i)).toHaveCount(0)
  await page.screenshot({ path: testInfo.outputPath('mentions-inbox-desktop.png'), fullPage: true })
  await page.getByRole('button', { name: 'Показать ещё' }).click()
  await expect(page.getByRole('button', { name: 'Перейти к упоминанию от Автор' })).toHaveCount(2)
  await page.getByRole('button', { name: 'Перейти к упоминанию от Автор' }).nth(1).click()
  await expect(page.getByTestId('opened-mention')).toHaveText(dmMention.message_id)
})

test('shows an empty state when the caller has no mentions', async ({ page }) => {
  await page.route('**/api/v1/mentions*', async (route) => { await route.fulfill({ json: { mentions: [] } }) })
  await page.reload()
  await page.getByRole('button', { name: 'Упоминания' }).click()
  await expect(page.getByText('Пока нет упоминаний.')).toBeVisible()
})
