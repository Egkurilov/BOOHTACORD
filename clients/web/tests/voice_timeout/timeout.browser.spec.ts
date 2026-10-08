import { expect, test, type Page } from '@playwright/test'
const account = '00000000-0000-4000-8000-000000000097'
const inactive = { active: false, revoked_leases: 0, revocation_pending: false }
async function open(page: Page): Promise<void> {
  await page.route('**/api/v1/admin/accounts?*', route => route.fulfill({ json: { accounts: [
    { account_id: account, login: 'selected', display_name: 'Participant', role: 'MEMBER', blocked: false, created_at: '2026-10-09T00:00:00Z' },
  ] } }))
  await page.goto('/tests/voice_timeout/fixture.html', { waitUntil: 'domcontentloaded' })
  if (page.viewportSize()!.width < 1024) await page.locator('.admin-mobile-card summary').click()
  else await page.getByRole('button', { name: 'Действия с участником Participant' }).click()
  await page.getByRole('button', { name: 'Ограничение голоса: selected', exact: true }).focus()
  await page.keyboard.press('Enter')
}
test('real member control reads lazily, confirms timeout and truthfully lifts pending removal', async ({ page }) => {
  let reads = 0, puts = 0, deletes = 0
  const mediaRequests: string[] = []
  page.on('request', request => { if (/voice-leases|livekit|media\/credentials/.test(request.url())) mediaRequests.push(request.url()) })
  await page.route(`**/api/v1/accounts/${account}/voice-timeout`, route => { reads++; return route.fulfill({ json: inactive }) })
  await page.route(`**/api/v1/admin/accounts/${account}/voice-timeout`, route => {
    if (route.request().method() === 'DELETE') { deletes++; return route.fulfill({ json: { ...inactive, revocation_pending: true } }) }
    puts++; const input = route.request().postDataJSON()
    expect(input.reason_code).toBe('SPAM')
    const remaining = Date.parse(input.expires_at) - Date.now()
    expect(remaining).toBeGreaterThan(14 * 60000); expect(remaining).toBeLessThanOrEqual(15 * 60000)
    return route.fulfill({ status: 202, json: { active: true, ...input, revoked_leases: 1, revocation_pending: true } })
  })
  await open(page)
  await expect(page.getByText('Активного ограничения голоса нет.', { exact: true })).toBeVisible()
  expect(reads).toBe(1)
  await page.getByLabel('Причина ограничения: selected', { exact: true }).selectOption('SPAM')
  await page.getByRole('button', { name: 'Подтвердить ограничение голоса: selected' }).click()
  await expect(page.getByText('Отключение поставлено в очередь.', { exact: false })).toBeVisible()
  await page.getByRole('button', { name: 'Снять ограничение голоса: selected' }).click()
  await expect(page.getByText('Активного ограничения голоса нет.', { exact: true })).toBeVisible()
  await expect(page.getByRole('button', { name: 'Снять ограничение голоса: selected' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Обновить ограничение голоса: selected' })).toBeFocused()
  expect(puts).toBe(1); expect(deletes).toBe(1); expect(mediaRequests).toEqual([])
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true)
})
test('forbidden mutation clears stale form and displays bounded feedback', async ({ page }) => {
  await page.route(`**/api/v1/accounts/${account}/voice-timeout`, route => route.fulfill({ json: inactive }))
  await page.route(`**/api/v1/admin/accounts/${account}/voice-timeout`, route => route.fulfill({ status: 403, body: 'private server details' }))
  await open(page)
  await page.getByRole('button', { name: 'Подтвердить ограничение голоса: selected' }).click()
  await expect(page.getByRole('alert')).toHaveText('Нет прав на управление голосом этого участника.')
  await expect(page.getByRole('button', { name: 'Подтвердить ограничение голоса: selected' })).toHaveCount(0)
  await expect(page.getByRole('button', { name: 'Обновить ограничение голоса: selected' })).toBeEnabled()
})
