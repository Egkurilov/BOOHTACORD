import { expect, it, vi } from 'vitest'
import { createVoiceDisconnectState } from './state'
it.each(['server-first', 'transport-first'])('preserves kick for %s', order => {
  const report = vi.fn(), state = createVoiceDisconnectState(report)
  state.bind('lease', 'channel')
  if (order === 'server-first') { state.server('lease', 'KICK'); state.transport() }
  else { state.transport(); state.server('lease', 'KICK') }
  expect(state.notice.value).toMatchObject({ reason: 'KICK', source: 'server', reconnectAllowed: true })
  expect(state.notice.value?.message).toBe('Администратор отключил вас от голосового канала.')
  expect(state.notice.value?.explanation).toContain('Автоматическое переподключение остановлено')
  state.local(); state.server('lease', 'KICK'); state.transport()
  expect(report).toHaveBeenCalledTimes(1)
  expect(report.mock.calls[0]?.[0]).toMatchObject({ reason: 'KICK', source: 'server' })
})
it('retains a lease during leave and rejects stale leases after new join', () => {
  const state = createVoiceDisconnectState(() => {})
  state.bind('lease', 'channel'); state.local(); state.transport(); state.server('lease', 'KICK')
  expect(state.notice.value?.reason).toBe('KICK')
  state.reset(); state.bind('new-lease', 'channel')
  expect(state.server('lease', 'KICK')).toBe(false)
  expect(state.notice.value).toBeNull()
})
it('blocks channel closure and revoked access but distinguishes transfer and network loss', () => {
  const state = createVoiceDisconnectState(() => {})
  for (const reason of ['CHANNEL_CLOSED', 'BANNED', 'SESSION_REVOKED', 'LOGOUT'] as const) {
    state.reset(); state.bind('lease', 'channel'); state.server('lease', reason)
    expect(state.notice.value?.reconnectAllowed).toBe(false)
  }
  state.reset(); state.bind('lease', 'channel'); state.server('lease', 'TRANSFER')
  expect(state.notice.value?.reconnectAllowed).toBe(true)
  state.selectChannel('other'); expect(state.notice.value).toBeNull()
  state.bind('transport', 'other'); state.transport()
  expect(state.notice.value?.source).toBe('transport')
})
