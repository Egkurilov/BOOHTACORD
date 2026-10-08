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
