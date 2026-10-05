import assert from 'node:assert/strict'
import { api, expect, origin, security, status } from './request.mjs'
export async function sessions(a, b, member, report, directory, redactions) {
  const own = (await api(a, '/me/sessions')).body
  assert.equal(own.sessions.length, 2)
  const foreign = (await api(member, '/me/sessions')).body
  const foreignHandle = foreign.sessions.find(row => row.current).id
  status(await api(a, '/me/sessions/'+foreignHandle, 'DELETE', undefined), 400)
  const denied = await a.context().request.delete(origin+'/api/v1/me/sessions/'+foreignHandle,
    { headers: { Origin: origin, 'X-Account-ID': own.account_id } })
  assert.equal(denied.status(), 404)
  let closed = false
  b.on('websocket', socket => {
    if (socket.url().includes('/api/v1/realtime')) socket.on('close', () => { closed = true })
  })
  await b.reload()
  await expect(b.getByRole('img', { name: 'В сети', exact: true })).toBeVisible()
  const oldCookies = await b.context().cookies()
  redactions.push(...oldCookies.map(cookie => cookie.value))
  assert.ok(oldCookies.some(cookie => cookie.name === 'vp_session' && cookie.path === '/'
    && cookie.httpOnly && cookie.secure && cookie.sameSite === 'Lax'))
  await security(a)
  await expect(a.getByTestId('session-revoke')).toHaveCount(2)
  assert.equal(await a.getByTestId('session-revoke').filter({ visible: true }).count(), 2)
  await a.locator('[data-testid="session-revoke"]:not([disabled])').click()
  await expect.poll(() => closed).toBe(true)
  const expired = await b.context().request.get(origin+'/api/v1/me/sessions', {
    headers: { Cookie: oldCookies.map(cookie => cookie.name+'='+cookie.value).join('; ') },
  })
  assert.equal(expired.status(), 401)
  status(await api(a, '/auth/session'), 200)
  status(await api(member, '/auth/session'), 200)
  await expect(a.getByTestId('session-revoke')).toHaveCount(1)
  await expect(a.getByTestId('session-revoke')).toBeDisabled()
  await a.screenshot({ path: directory+'/own-sessions.png' })
  report.sessions = { secure_cookie: true, foreign_handle_denied: true,
    old_cookie_denied: true, old_socket_closed: true, initiating_session_preserved: true, foreign_session_preserved: true }
}
