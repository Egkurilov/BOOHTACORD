import { describe, expect, it } from 'vitest'

import { parseRealtimeEvent, realtimeURL } from './realtime_client'

describe('realtime client contract', () => {
  it('uses the same host and no credential in its websocket URL', () => {
    expect(realtimeURL({ protocol: 'https:', host: 'voice.example.test' })).toBe('wss://voice.example.test/api/v1/realtime')
  })

  it('accepts only schema event kinds and typed payloads', () => {
    expect(parseRealtimeEvent({ event_id: 'event-1', kind: 'connection.resync_required', occurred_at: '2026-09-17T12:00:00Z', payload: { reason: 'replay_unavailable' } })).toMatchObject({ kind: 'connection.resync_required' })
    expect(() => parseRealtimeEvent({ kind: 'unknown' })).toThrow('некорректное')
  })
})
