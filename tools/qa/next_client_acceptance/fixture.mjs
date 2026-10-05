import assert from 'node:assert/strict'
import { randomUUID } from 'node:crypto'
import { execFileSync } from 'node:child_process'
import { api, status } from '../client_lifecycle/request.mjs'
export { api, status, expect, login, chromium } from '../client_lifecycle/request.mjs'
export function owned(role, ...command) {
  const owner = process.env.QA_DB_OWNER
  assert.match(owner, /^qa-client-[a-f0-9]{16}$/)
  assert.ok(['db', 'sfu', 'keeper', 'api'].includes(role))
  const name = owner+'-'+role
  assert.equal(execFileSync('docker', ['inspect', name, '--format', '{{index .Config.Labels "boohtacord.qa.owner"}}'], { encoding: 'utf8' }).trim(), owner)
  return execFileSync('docker', command.map(value => value === '$owned' ? name : value), { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim()
}
export function sql(statement) { return owned('db', 'exec', '$owned', 'psql', '-U', 'qa', '-d', 'qa', '-At', '-v', 'ON_ERROR_STOP=1', '-c', statement) }
export async function freshUploadWindow(page) {
  // Separate cancellation, ten-file and DM checks: the native limit is ten attempts per five minutes.
  // Restart only the owned API, preserving actual DB, files, cookies and the native policy.
  owned('api', 'restart', '$owned')
  for (let attempt=0; attempt<100; attempt++) {
    try { if ((await api(page,'/health')).status===200) return } catch { /* startup */ }
    await page.waitForTimeout(100)
  }
  throw new Error('Owned API did not recover before independent upload scenario')
}
export async function channel(page, category, name, kind='TEXT') {
  const result = await api(page, `/admin/categories/${category}/channels`, 'POST', { name, kind })
  status(result, 201); return result.body.id
}
export async function setup(page, password) {
  const category = await api(page, '/admin/categories', 'POST', { name: 'NextLab' }); status(category, 201)
  const a = await channel(page, category.body.id, 'NextA'), b = await channel(page, category.body.id, 'NextB')
  const registered = await api(page, '/auth/register', 'POST', { login: 'qa_next_member', password }); status(registered, 201)
  const dm = await api(page, '/direct-messages', 'POST', { participant_id: registered.body.id }); status(dm, 201)
  return { category: category.body.id, a, b, dm: dm.body.id, member: registered.body.id,
    admin: sql("SELECT id FROM users WHERE login='qa_admin'") }
}
export async function select(page, name) {
  await page.getByRole('button', { name: 'Каналы', exact: true }).click()
  await page.locator('.channel-button').filter({ hasText: name }).click()
}
export function seed(fixture, kind, count=121) {
  const ids = Array.from({ length: count }, () => randomUUID())
  const table = kind === 'CHANNEL' ? 'messages' : 'direct_message_messages'
  const target = kind === 'CHANNEL' ? 'channel_id' : 'direct_message_id'
  const scope = kind === 'CHANNEL' ? fixture.a : fixture.dm
  const rows = ids.map((id, i) => `('${id}','${scope}','${i===10 ? fixture.admin : fixture.member}','${randomUUID()}','QA history ${i}',TIMESTAMPTZ '2026-01-01' + INTERVAL '${i} seconds')`)
  sql(`INSERT INTO ${table}(id,${target},author_id,client_message_id,body,created_at) VALUES ${rows.join(',')}`)
  return { ids, table, target, scope }
}
