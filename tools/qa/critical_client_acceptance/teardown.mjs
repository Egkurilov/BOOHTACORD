import assert from 'node:assert/strict'
import { api, expect, login, security, status } from '../client_lifecycle/request.mjs'
async function join(page) {
  await page.locator('.channel-button').filter({ hasText: 'VoiceLab' }).click()
  await page.getByRole('button', { name: 'Подключиться без микрофона', exact: true }).click()
  await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён')
}
async function mediaClosed(page) {
  await expect.poll(() => page.evaluate(() => window.__qaPeers.every(peer => peer.connectionState !== 'connected'))).toBe(true)
}
export async function teardown(a, b, channelId, input, report) {
  await join(a)
  await a.locator('.channel-button').filter({ hasText: 'WelcomeLab' }).click()
  let release, waiting = false
  const routed = []
  const held = new Promise(resolve => { release = resolve })
  const pattern = `**/api/v1/channels/${channelId}/messages*`
  await a.route(pattern, route => {
    const work = (async () => {
      if (route.request().method() === 'GET') { waiting = true; await held }
      try { await route.continue() }
      catch (error) { if (!error.message.includes('Route is already handled') && !error.message.includes('has been closed')) throw error }
    })()
    routed.push(work)
    return work
  })
  try {
    status(await api(b, `/channels/${channelId}/messages`, 'POST', {
      client_message_id: crypto.randomUUID(), body: 'Synthetic blocked refresh',
    }), 201)
    await expect.poll(() => waiting).toBe(true)
    const account = (await api(b, '/auth/session')).body.account_id
    const kick = await api(b, `/admin/accounts/${account}/voice-kick`, 'POST')
    status(kick, 200)
    assert.equal(kick.body.revoked_leases, 1)
    await expect(a.getByTestId('voice-dock')).not.toHaveClass(/connected/)
    await mediaClosed(a)
    report.connection_status.lease_revoke_during_blocked_rest = true
  } finally { release(); await Promise.all(routed); await a.unroute(pattern) }
  await join(a)
  await security(a)
  await a.getByRole('button', { name: 'Выйти из аккаунта', exact: true }).click()
  await expect(a.locator('.authentication-page')).toBeVisible()
  await mediaClosed(a)
  await expect(a.getByTestId('connection-status')).toHaveCount(0)
  await expect(a.getByTestId('voice-dock')).toHaveCount(0)
  report.connection_status.logout_clears_voice_and_roster = true
  await login(a, 'qa_admin', input.password)
}
