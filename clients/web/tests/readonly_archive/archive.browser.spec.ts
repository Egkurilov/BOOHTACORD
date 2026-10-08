import { expect, test } from '@playwright/test'
const id = '11111111-1111-4111-8111-111111111111', author = '22222222-2222-4222-8222-222222222222'
const message = { id: '33333333-3333-4333-8333-333333333333', channel_id: id, author_id: author, client_message_id: '44444444-4444-4444-8444-444444444444', body: '<script>unsafe()</script>', created_at: '2026-10-08T10:00:00Z', revision: 1, mention_user_ids: [], attachments: [{ id: 'file', original_name: 'history.txt', byte_size: 12 }] }
const archive = { id, name: 'History', description: '', category_name: 'General', archived_at: '2026-10-08T11:00:00Z' }
async function open(page: import('@playwright/test').Page, admin = false) {
  await page.route('**/api/v1/members**', route => route.fulfill({ json: { members: [] } }))
  await page.route('**/api/v1/archives/text-channels', route => route.fulfill({ json: { revision: 4, can_manage: admin, channels: [archive] } }))
  await page.route(`**/api/v1/archives/text-channels/${id}/messages**`, route => route.fulfill({ json: { messages: [message], ...(new URL(route.request().url()).searchParams.has('before') ? {} : { next_cursor: message.id }) } }))
  await page.goto('/tests/readonly_archive/fixture.html'); await page.getByRole('button', { name: 'Архив', exact: true }).click()
  await page.getByLabel('Канал', { exact: true }).selectOption(id)
}
test('real reader preserves readonly history pagination, escaped text, protected file and search', async ({ page }) => {
  await open(page)
  await expect(page.getByText('<script>unsafe()</script>', { exact: true })).toBeVisible()
  await expect(page.locator('.archive-messages script')).toHaveCount(0)
  await expect(page.getByRole('link', { name: 'history.txt' })).toHaveAttribute('href', `/api/v1/archives/text-channels/${id}/attachments/file`)
  await expect(page.getByRole('group', { name: 'Управление архивом' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Отправить', exact: true })).toHaveCount(0)
  await page.getByRole('button', { name: 'Показать ещё' }).click(); await expect(page.locator('.archive-messages article')).toHaveCount(2)
  await page.route(`**/api/v1/archives/text-channels/${id}/search**`, route => route.fulfill({ json: { messages: [{ ...message, kind: 'CHANNEL' }] } }))
  await page.getByRole('searchbox').fill('orbit'); await page.getByRole('button', { name: 'Найти', exact: true }).click()
  await expect(page.locator('.archive-messages article')).toHaveCount(1)
  await page.getByRole('button', { name: 'Завершить сессию' }).click(); await expect(page.locator('.archive-messages')).toHaveCount(0)
})
test('admin archive needs explicit confirmation and revision; restore conflict is visible', async ({ page }) => {
  await page.route('**/api/v1/channels', route => route.fulfill({ json: { revision: 4, categories: [{ id, name: 'General', position: 0, channels: [{ id, name: 'Active', kind: 'TEXT', position: 0, admission_closed: false, unread_count: 0, mention_count: 0 }] }] } }))
  let body: unknown
  await page.route(`**/api/v1/admin/text-channels/${id}/readonly-archive`, route => { body = route.request().postDataJSON(); return route.fulfill({ json: { id, revision: 5 } }) })
  await page.route(`**/api/v1/admin/archives/text-channels/${id}/restore`, route => route.fulfill({ status: 409 }))
  await open(page, true)
  await page.getByRole('button', { name: 'Восстановить выбранный канал' }).click(); await expect(page.getByRole('group', { name: 'Управление архивом' }).getByRole('alert')).toContainText('409')
  await page.getByLabel('Активный TEXT-канал').selectOption(id)
  await expect(page.getByRole('button', { name: 'Архивировать', exact: true })).toBeDisabled()
  await page.getByRole('checkbox').check(); await page.getByRole('button', { name: 'Архивировать', exact: true }).click()
  await expect.poll(() => body).toEqual({ expected_revision: 4, confirm: true })
})
