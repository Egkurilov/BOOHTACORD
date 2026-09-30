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
      const source: VoiceRosterEvents = { onmessage: null, onerror: null, close: vi.fn() }
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
})
