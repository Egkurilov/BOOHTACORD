import { describe, expect, it } from 'vitest'
import { useGuildPresence } from './guild_presence'

describe('authenticated guild presence state', () => {
  it('treats a complete realtime snapshot as authoritative and applies later changes', () => {
    const presence = useGuildPresence()
    const accepted = presence.acceptRealtimeEvent({ kind: 'presence.snapshot', payload: { online_user_ids: ['user-1'] } })
    expect(accepted).toBe(true)
    expect(presence.resolve('user-1', 'unknown')).toBe('online')
    expect(presence.resolve('user-2', 'unknown')).toBe('offline')

    presence.acceptRealtimeEvent({ kind: 'presence.changed', payload: { user_id: 'user-2', presence: 'online' } })
    expect(presence.resolve('user-2', 'offline')).toBe('online')
    presence.acceptRealtimeEvent({ kind: 'presence.changed', payload: { user_id: 'user-1', presence: 'offline' } })
    expect(presence.resolve('user-1', 'online')).toBe('offline')
  })

  it('preserves unknown when events are incomplete or unavailable', () => {
    const presence = useGuildPresence()
    expect(presence.acceptRealtimeEvent({ kind: 'presence.snapshot', payload: { online_user_ids: 'invalid' } })).toBe(true)
    expect(presence.resolve('user-1', 'unknown')).toBe('unknown')
    expect(presence.acceptRealtimeEvent({ kind: 'presence.changed', payload: { user_id: 'user-1', presence: 'away' } })).toBe(true)
    expect(presence.resolve('user-1', 'unknown')).toBe('unknown')
    expect(presence.acceptRealtimeEvent({ kind: 'message.created', payload: {} })).toBe(false)
    presence.invalidate()
    expect(presence.resolve('user-2', 'offline')).toBe('unknown')
  })
})
