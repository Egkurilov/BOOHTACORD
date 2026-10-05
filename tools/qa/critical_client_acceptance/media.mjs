import assert from 'node:assert/strict'
import { api, expect, status } from '../client_lifecycle/request.mjs'
import { owned } from './control.mjs'
import { teardown } from './teardown.mjs'
async function connected(page) {
  await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён')
  await expect.poll(() => page.evaluate(() => window.__qaPeers.some(peer => peer.connectionState === 'connected'))).toBe(true)
}
export async function media(a, b, member, channelId, report, input) {
  const directory = input.directory
  let blocked = false
  const chat = []
  await a.addInitScript(() => {
    window.__qaPeers = []
    const Native = window.RTCPeerConnection
    window.RTCPeerConnection = new Proxy(Native, { construct(target, args) {
      const peer = Reflect.construct(target, args); window.__qaPeers.push(peer); return peer
    } })
  })
  await a.routeWebSocket(url => new URL(url).pathname === '/api/v1/realtime', socket => {
    if (blocked) { socket.close(); return }
    const server = socket.connectToServer(); chat.push({ socket, server })
  })
  await a.reload()
  const category = await api(a, '/admin/categories', 'POST', { name: 'VoiceLab' }); status(category, 201)
  const room = await api(a, `/admin/categories/${category.body.id}/channels`, 'POST', { name: 'VoiceLab', kind: 'VOICE' }); status(room, 201)
  for (const page of [a, member]) {
    await page.locator('.channel-button').filter({ hasText: 'VoiceLab' }).click()
    await page.getByRole('button', { name: 'Подключиться без микрофона', exact: true }).click()
    await expect(page.getByTestId('voice-dock').locator('.voice-status')).toHaveText('Голос подключён')
  }
  await connected(a)
  blocked = true
  for (const { socket, server } of chat) { server.close(); socket.close() }
  const banner = a.getByTestId('connection-status')
  await expect(banner).toContainText('Чат обновляется')
  await expect(banner).toContainText('Голос подключён')
  await connected(a)
  await a.screenshot({ path: directory+'/chat-failed-media-connected.png' })
  blocked = false
  await banner.getByRole('button', { name: 'Повторить связь чата' }).click()
  await expect(banner).toBeHidden()
  // Both listeners now have real WebRTC transports; stop only the owned SFU.
  owned('sfu', 'stop', '$owned')
  try {
    await expect(banner).toContainText('Состав недоступен', { timeout: 20000 })
    await expect(a.getByRole('log')).toHaveCount(0)
    assert.equal(await a.getByText('Пока никого нет.', { exact: true }).count(), 0)
    await a.screenshot({ path: directory+'/sfu-unavailable.png' })
    report.connection_status = { ws_only_failure_real_webrtc_alive: true, targeted_chat_retry: true,
      sfu_failure_not_empty_room: true, last_roster_age_visible: /с\. назад/.test(await banner.innerText()) }
    assert.equal(report.connection_status.last_roster_age_visible, true)
  } finally { owned('sfu', 'start', '$owned') }
  await expect.poll(async () => (await api(a, '/voice/participants')).status, { timeout: 30000 }).toBe(200)
  await banner.getByRole('button', { name: 'Обновить состав' }).click()
  await expect.poll(async () => await banner.count() === 0 || !(await banner.innerText()).includes('Состав недоступен')).toBe(true)
  for (const page of [a, member]) {
    const leave = page.getByTestId('voice-dock').getByRole('button', { name: 'Выйти из голосового канала', exact: true })
    if (await leave.count()) await leave.click()
  }
  await a.locator('.channel-button').filter({ hasText: 'WelcomeLab' }).click()
  await b.locator('.channel-button').filter({ hasText: 'WelcomeLab' }).click()
  report.connection_status.targeted_roster_retry = true
  await teardown(a, b, channelId, input, report)
}
