import assert from 'node:assert/strict'
import { api, channel, expect, guildPanel, status } from './request.mjs'
export async function guild(a, b, guest, password, report, directory) {
  const category = await api(a, '/admin/categories', 'POST', { name: 'AutonomousLab' })
  status(category, 201)
  const target = await api(a, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'WelcomeLab', kind: 'TEXT' })
  status(target, 201)
  await expect(b.locator('.channel-button').filter({ hasText: 'WelcomeLab' })).toBeVisible()
  await guildPanel(a)
  const settings = (await api(a, '/admin/guild-settings')).body
  await a.getByLabel('Название гильдии', { exact: true }).fill('Автономная гильдия')
  await a.getByLabel('Приветствия новых участников').selectOption(target.body.id)
  await a.getByRole('button', { name: 'Сохранить', exact: true }).click()
  await expect(a.getByRole('status').filter({ hasText: 'Настройки сохранены' })).toBeVisible()
  await expect(b.locator('#app-title')).toHaveText('Автономная гильдия')
  await expect(b).toHaveTitle('Автономная гильдия')
  const publicProfile = (await api(guest, '/guild-profile')).body
  assert.deepEqual(Object.keys(publicProfile).sort(), ['name', 'revision'])
  status(await api(b, '/admin/guild-settings', 'PATCH', { name: 'StaleOverwrite', expected_revision: settings.revision }), 409)
  const denied = await a.context().request.patch(new URL('/api/v1/admin/guild-settings', process.env.QA_ORIGIN).href,
    { headers: { Origin: 'https://foreign.invalid' }, data: { name: 'Foreign', expected_revision: publicProfile.revision } })
  assert.equal(denied.status(), 403)
  report.guild = { live_rename: true, private_profile: true, revision_conflict: true, origin_denied: true }
  await a.screenshot({ path: directory+'/guild-settings.png' })
  await channel(a); await channel(b)
  const registered = await api(guest, '/auth/register', 'POST', { login: 'qa_member', password })
  status(registered, 201)
  for (const page of [a, b]) {
    await expect(page.getByLabel('Системное приветствие', { exact: true })).toHaveCount(1)
    await expect(page.getByLabel('Системное приветствие', { exact: true })).toContainText('@qa_member')
  }
  const history = (await api(a, `/channels/${target.body.id}/messages`)).body
  const rows = history.messages.filter(row => row.kind === 'SYSTEM_WELCOME')
  assert.equal(rows.length, 1)
  await b.reload(); await channel(b)
  await expect(b.getByLabel('Системное приветствие', { exact: true })).toHaveCount(1)
  const retry = await api(guest, '/auth/register', 'POST', { login: 'qa_member', password })
  status(retry, 409)
  await a.screenshot({ path: directory+'/welcome-a.png' })
  await b.screenshot({ path: directory+'/welcome-b.png' })
  report.welcome = { two_live_clients: true, reconnect_single: true, retry_no_duplicate: true }
  return { channelId: target.body.id, accountId: registered.body.id, message: rows[0], revision: publicProfile.revision }
}
