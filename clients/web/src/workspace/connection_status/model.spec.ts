import { describe, expect, it, vi } from 'vitest'
import { connectionStatus } from './model'
import { createVoiceRosterRealtime, type VoiceRosterEvents } from '../../voice/voice_roster_realtime'

describe('independent chat, media and roster state', () => {
  it('does not mark connected media offline when only chat fails', () => {
    const status = connectionStatus('DISCONNECTED', 'CONNECTED', false, 1000, 6000)
    expect(status.chat).toBe('Чат обновляется')
    expect(status.voice).toBe('Голос подключён')
    expect(status.roster).toContain('Состав устарел')
  })
  it('distinguishes an unknown snapshot from an actual empty successful roster', () => {
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, null, 6000).roster).toBe('Состав недоступен')
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, 1000, 6000).roster).toContain('Состав устарел')
    expect(connectionStatus('CONNECTED', 'RECONNECTING', true, 1000, 6000).voice).toBe('Голос восстанавливается')
  })
  it('marks a retained roster stale and unavailable without a snapshot', () => {
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, 1000, 6000).roster).toContain('Состав устарел')
    expect(connectionStatus('CONNECTED', 'CONNECTED', false, null, 6000).roster).toBe('Состав недоступен')
  })
  it('tracks last successful update and clears ownership on stop', () => {
    const source: VoiceRosterEvents = { onmessage: null, onerror: null, addEventListener: vi.fn(), close: vi.fn() }
    const roster = createVoiceRosterRealtime(() => source)
    roster.start()
    source.onmessage?.({ data: JSON.stringify({ channels: [] }) })
    const before = roster.lastUpdatedAt.value
    expect(before).not.toBeNull()
    source.onerror?.()
    expect(roster.error.value).not.toBeNull()
    expect(roster.lastUpdatedAt.value).toBe(before)
    roster.stop()
    expect(roster.lastUpdatedAt.value).toBeNull()
  })
})
