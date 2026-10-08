import { describe, expect, it, vi } from 'vitest'

import {
  createVoiceRosterRealtime,
  createVoiceRosterReconnectGate,
  type VoiceRosterEvents,
} from './voice_roster_realtime'

describe('voice roster event stream', () => {
  it('does not reopen the roster stream for the initial realtime connection', () => {
    const shouldReconnect = createVoiceRosterReconnectGate()

    expect(shouldReconnect()).toBe(false)
    expect(shouldReconnect()).toBe(true)
  })

  it('refreshes when the workspace mounted with an already-connected realtime socket', () => {
    const shouldReconnect = createVoiceRosterReconnectGate(true)

    expect(shouldReconnect()).toBe(true)
  })

  it('uses one server-pushed stream, updates from events, and closes on stop', () => {
    const sources: VoiceRosterEvents[] = []
    const factory = vi.fn(() => {
      const source: VoiceRosterEvents = { onmessage: null, onerror: null, addEventListener: vi.fn(), close: vi.fn() }
      sources.push(source)
      return source
    })
    const roster = createVoiceRosterRealtime(factory)
    roster.start()
    expect(factory).toHaveBeenCalledWith('/api/v1/voice/rosters/events')
    sources[0].onmessage?.({ data: JSON.stringify({ channels: [{ channel_id: 'room', participants: [] }] }) })
    expect(roster.channels.value).toEqual([{ channelId: 'room', participants: [] }])
    sources[0].onerror?.()
    expect(roster.channels.value).toEqual([{ channelId: 'room', participants: [] }])
    roster.stop()
    expect(sources[0].close).toHaveBeenCalledOnce()
    expect(roster.channels.value).toBeNull()
  })

  it('keeps start idempotent while explicit reconnect replaces the stream', () => {
    const sources: VoiceRosterEvents[] = []
    const factory = vi.fn(() => {
      const source: VoiceRosterEvents = { onmessage: null, onerror: null, addEventListener: vi.fn(), close: vi.fn() }
      sources.push(source)
      return source
    })
    const roster = createVoiceRosterRealtime(factory)

    roster.start()
    roster.start()
    expect(factory).toHaveBeenCalledOnce()

    roster.reconnect()
    expect(factory).toHaveBeenCalledTimes(2)
    expect(sources[0].close).toHaveBeenCalledOnce()
    roster.stop()
  })

  it('keeps a successful snapshot explicitly stale on roster-unavailable', () => {
    const listeners = new Map<string, EventListener>()
    const source: VoiceRosterEvents = {
      onmessage: null,
      onerror: null,
      addEventListener: vi.fn((type: string, listener: EventListener) => listeners.set(type, listener)),
      close: vi.fn(),
    }
    const roster = createVoiceRosterRealtime(() => source)
    roster.start()
    source.onmessage?.({ data: JSON.stringify({ channels: [{ channel_id: 'room', participants: [] }] }) })
    expect(roster.status.value).toBe('fresh')
    listeners.get('roster-unavailable')?.(new Event('roster-unavailable'))

    expect(roster.status.value).toBe('stale_reconnecting')
    expect(roster.channels.value).toEqual([{ channelId: 'room', participants: [] }])
    expect(roster.lastUpdatedAt.value).not.toBeNull()
    expect(roster.error.value).toBe('Не удалось обновить состав голосовых каналов.')
    roster.stop()
  })

  it('does not confuse successful empty and unavailable snapshots', () => {
    const listeners = new Map<string, EventListener>()
    const source: VoiceRosterEvents = {
      onmessage: null,
      onerror: null,
      addEventListener: vi.fn((type: string, listener: EventListener) => listeners.set(type, listener)),
      close: vi.fn(),
    }
    const roster = createVoiceRosterRealtime(() => source)
    roster.start()
    source.onmessage?.({ data: JSON.stringify({ channels: [] }) })
    expect(roster.status.value).toBe('fresh_empty')
    listeners.get('roster-unavailable')?.(new Event('roster-unavailable'))

    expect(roster.status.value).toBe('stale_reconnecting')
    expect(roster.channels.value).toEqual([])
    roster.stop()
  })

  it('closes the browser EventSource and expires the workspace session on revocation', () => {
    const listeners = new Map<string, EventListener>()
    const source: VoiceRosterEvents = {
      onmessage: null,
      onerror: null,
      addEventListener: vi.fn((type: string, listener: EventListener) => listeners.set(type, listener)),
      close: vi.fn(),
    }
    const onSessionExpired = vi.fn()
    const roster = createVoiceRosterRealtime(() => source, onSessionExpired)

    roster.start()
    listeners.get('session-expired')?.(new Event('session-expired'))

    expect(source.close).toHaveBeenCalledOnce()
    expect(roster.status.value).toBe('session_expired')
    expect(roster.channels.value).toBeNull()
    expect(onSessionExpired).toHaveBeenCalledOnce()
  })
})
