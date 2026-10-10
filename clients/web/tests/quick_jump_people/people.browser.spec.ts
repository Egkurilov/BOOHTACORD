import { expect, test } from '@playwright/test'

test('actual search lists eligible guild people, retries pages and opens an authoritative DM without Join', async ({ page }) => {
  let joined = 0, writes = 0, next = 0
  await page.route('**/api/v1/**', async route => {
    const path = new URL(route.request().url()).pathname
    if (/voice.*lease|voice.*join/.test(path)) joined++
    if (path.endsWith('/direct-message-candidates')) {
      if (!new URL(route.request().url()).search) return route.fulfill({ json: { candidates: [{ id: 'alice', display_name: 'Алиса' }, { id: 'bob', display_name: 'Боб' }], next_after: 'bob' } })
      if (++next === 1) return route.fulfill({ status: 503, json: {} })
      return route.fulfill({ json: { candidates: [{ id: 'zoe', display_name: 'Зоя' }] } })
    }
    if (path.endsWith('/direct-messages')) {
      if (route.request().method() === 'POST') {
        writes++; expect(route.request().postDataJSON()).toEqual({ participant_id: 'bob' })
        return route.fulfill({ status: 201, json: { id: 'bob-dm', participant_one_id: 'self', participant_two_id: 'bob', created_at: '2026-01-01T00:00:00Z' } })
      }
      return route.fulfill({ json: { direct_messages: [{ id: 'bob-dm', other_participant_id: 'bob', other_participant_display_name: 'Боб', created_at: '2026-01-01T00:00:00Z', unread_count: 0, mention_count: 0 }] } })
    }
    return route.fulfill({ json: { messages: [], mentions: [] } })
  })
  await page.goto('/tests/quick_jump_people/fixture.html')
  await page.getByRole('button', { name: 'Каналы и люди', exact: true }).click()
  const panel = page.getByTestId('quick-jump-panel')
  await expect(panel.locator('[data-kind="DIRECT_MESSAGE"]')).toHaveCount(1)
  await expect(panel.locator('[data-kind="MEMBER"]')).toHaveCount(1)
  await panel.getByRole('button', { name: 'Показать ещё участников' }).click()
  await expect(panel.getByRole('alert')).toContainText('Не удалось')
  await expect(panel.getByRole('button', { name: 'Боб Участник гильдии' })).toBeVisible()
  await panel.getByRole('button', { name: 'Повторить', exact: true }).click()
  await expect(panel.getByRole('button', { name: 'Зоя Участник гильдии' })).toBeVisible()
  await panel.getByRole('searchbox').fill('Боб')
  await panel.getByRole('button', { name: 'Боб Участник гильдии' }).click()
  await expect(page.getByTestId('selected')).toHaveText('bob-dm')
  expect(writes).toBe(1); expect(joined).toBe(0)
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
})

for (const status of [403, 404]) {
  test(`keeps an unavailable participant in the safe error flow after HTTP ${status}`, async ({ page }) => {
    let opened = 0, joined = 0
    await page.route('**/api/v1/**', async route => {
      const path = new URL(route.request().url()).pathname
      if (/voice.*lease|voice.*join/.test(path)) joined++
      if (path.endsWith('/direct-message-candidates')) {
        return route.fulfill({ json: { candidates: [{ id: 'bob', display_name: 'Боб' }] } })
      }
      if (path.endsWith('/direct-messages')) {
        if (route.request().method() === 'POST') {
          opened++
          return route.fulfill({ status, json: { error: { code: status === 403 ? 'forbidden' : 'not_found' } } })
        }
        return route.fulfill({ json: { direct_messages: [] } })
      }
      return route.fulfill({ json: { messages: [], mentions: [] } })
    })
    await page.goto('/tests/quick_jump_people/fixture.html')
    await page.getByRole('button', { name: 'Каналы и люди', exact: true }).click()
    const panel = page.getByTestId('quick-jump-panel')
    await panel.getByRole('button', { name: 'Боб Участник гильдии' }).click()
    await expect(page.getByRole('alert')).toHaveText('Личный диалог больше недоступен.')
    expect(opened).toBe(1)
    expect(joined).toBe(0)
    await expect(page.getByTestId('selected')).toHaveText('')
  })
}

test('does not navigate to a DM mention after an authoritative refresh reports the target missing', async ({ page }) => {
  await page.route('**/api/v1/mentions*', async route => {
    return route.fulfill({ json: { mentions: [{
      kind: 'DIRECT_MESSAGE', message_id: '55555555-5555-4555-8555-555555555555',
      conversation_id: '66666666-6666-4666-8666-666666666666',
      author_id: '44444444-4444-4444-8444-444444444444', created_at: '2026-10-08T10:00:00Z',
    }] } })
  })
  await page.route('**/api/v1/direct-messages', async route => {
    return route.fulfill({ json: { direct_messages: [] } })
  })
  await page.route('**/members/44444444-4444-4444-8444-444444444444', async route => {
    return route.fulfill({ json: { user_id: '44444444-4444-4444-8444-444444444444', login: 'author', display_name: 'Автор', role: 'MEMBER', presence: 'online' } })
  })
  await page.goto('/tests/quick_jump_people/fixture.html')
  await page.getByRole('button', { name: 'Упоминания' }).click()
  await page.getByRole('button', { name: 'Перейти к упоминанию от Автор' }).click()
  await expect(page.getByRole('alert')).toHaveText('Личный диалог больше недоступен.')
  await expect(page.getByTestId('selected')).toHaveText('')
})
