import { owned } from './control.mjs'
import { api, expect, origin, status } from '../client_lifecycle/request.mjs'
export async function resetLinks(browser, admin, accountId, input, report, redactions) {
  const context = await browser.newContext({ ignoreHTTPSErrors: true })
  try {
    const page = await context.newPage()
    const created = await api(admin, '/admin/password-reset-links', 'POST', { account_id: accountId })
    status(created, 201)
    const token = new URL(created.body.url).hash
    redactions.push(token, new URLSearchParams(token.slice(1)).get('token'))
    const url = origin+'/reset-password'+token
    await page.goto(url)
    await expect(page).toHaveURL(origin+'/reset-password')
    async function submit() {
      await page.getByLabel('Новый пароль', { exact: true }).fill(input.password+'🙂é')
      await page.getByLabel('Повторите пароль', { exact: true }).fill(input.password+'🙂é')
      await page.getByRole('button', { name: 'Изменить пароль', exact: true }).click()
    }
    await submit()
    await expect(page.getByRole('status')).toContainText('Пароль изменён')
    await expect(page.getByRole('status')).toBeFocused()
    await page.goto(url)
    await submit()
    await expect(page.getByRole('alert')).toContainText('срок её действия истёк')
    await expect(page.getByRole('alert')).toBeFocused()
    await page.getByRole('button', { name: 'Перейти ко входу' }).click()
    await expect(page.getByLabel('Логин', { exact: true })).toBeFocused()
    const next = await api(admin, '/admin/password-reset-links', 'POST', { account_id: accountId })
    status(next, 201)
    const nextToken = new URL(next.body.url).hash
    redactions.push(nextToken, new URLSearchParams(nextToken.slice(1)).get('token'))
    // Expire only the owned disposable fixture's resets; no production clock or data mutation.
    owned('db', 'exec', '$owned', 'psql', '-U', 'qa', '-d', 'qa', '-c',
      "update password_resets set expires_at = now() - interval '1 second' where used_at is null")
    await page.goto(origin+'/reset-password'+nextToken)
    await submit()
    await expect(page.getByRole('alert')).toContainText('срок её действия истёк')
    await expect(page.getByRole('alert')).toBeFocused()
    await page.screenshot({ path: input.directory+'/password-reset-expired.png' })
    report.authentication.reset = { used_rejected: true, expired_rejected: true, result_focus: true, return_login_focus: true, fragment_removed: true }
  } finally { await context.close() }
}
