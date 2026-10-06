import { describe, expect, it } from 'vitest'

import { parseRealtimeEvent, realtimeURL, realtimeTraceURL } from './realtime_client'

describe('realtime client contract', () => {
  it('uses the same host and no credential in its websocket URL', () => {
    expect(realtimeURL({ protocol: 'https:', host: 'voice.example.test' })).toBe('wss://voice.example.test/api/v1/realtime?capabilities=role_permissions_v1,flow_tracing_v1')
  })

  it('carries a W3C traceparent through the browser WebSocket handshake', () => {
    const parent = '00-11111111111111111111111111111111-2222222222222222-01'
    expect(realtimeTraceURL('wss://voice.example.test/api/v1/realtime?after=cursor', parent)).toBe(`wss://voice.example.test/api/v1/realtime?after=cursor&traceparent=${parent}`)
    expect(new URL(realtimeTraceURL('wss://voice.example.test/api/v1/realtime', parent, 'vendor=state')).searchParams.get('tracestate')).toBe('vendor=state')
  })

  it('accepts only schema event kinds and typed payloads', () => {
    expect(parseRealtimeEvent({ event_id: 'event-1', kind: 'connection.resync_required', occurred_at: '2026-09-17T12:00:00Z', payload: { reason: 'replay_unavailable' } })).toMatchObject({ kind: 'connection.resync_required' })
    expect(() => parseRealtimeEvent({ kind: 'unknown' })).toThrow('некорректное')
  })
})
