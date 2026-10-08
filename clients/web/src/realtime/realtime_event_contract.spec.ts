import { describe, expect, it } from 'vitest'

import { parseRealtimeEvent } from './realtime_client'

const id = '11111111-1111-4111-8111-111111111111'
const message = '22222222-2222-4222-8222-222222222222'
function event(kind: string, payload: Record<string, unknown>) {
  return { event_id: '33333333-3333-4333-8333-333333333333', occurred_at: '2026-09-25T00:00:00Z', kind, payload }
}

describe('typed realtime payloads', () => {
  it('accepts exact private DM hints and topology/voice revisions', () => {
    expect(parseRealtimeEvent(event('direct_message.message_created', { direct_message_id: id, message_id: message })).kind).toBe('direct_message.message_created')
    expect(parseRealtimeEvent(event('direct_message.message_updated', { direct_message_id: id, message_id: message, revision: 2 })).kind).toBe('direct_message.message_updated')
    expect(parseRealtimeEvent(event('direct_message.message_deleted', { direct_message_id: id, message_id: message, revision: 3 })).kind).toBe('direct_message.message_deleted')
    expect(parseRealtimeEvent(event('channel.updated', { revision: 7 })).kind).toBe('channel.updated')
    expect(parseRealtimeEvent(event('member.profile.updated', { user_id: id, revision: 9 })).kind).toBe('member.profile.updated')
    expect(parseRealtimeEvent(event('voice.lease_revoked', { lease_id: id, reason: 'KICK' })).kind).toBe('voice.lease_revoked')
    expect(parseRealtimeEvent(event('role.permissions.updated', { role: 'MEMBER', revision: 8 })).kind).toBe('role.permissions.updated')
    expect(parseRealtimeEvent(event('auth.permissions.invalidated', {})).kind).toBe('auth.permissions.invalidated')
  })

  it('rejects malformed or content-bearing private hints', () => {
    for (const payload of [
      { direct_message_id: id },
      { direct_message_id: id, message_id: message, body: 'secret' },
      { direct_message_id: 'bad', message_id: message },
    ]) expect(() => parseRealtimeEvent(event('direct_message.message_created', payload))).toThrow('Некорректное')
    for (const kind of ['direct_message.message_updated', 'direct_message.message_deleted']) {
      for (const revision of [undefined, 0, -1, 1.5]) {
        expect(() => parseRealtimeEvent(event(kind, { direct_message_id: id, message_id: message, revision }))).toThrow('Некорректное')
      }
    }
  })

  it('rejects unexpected topology and revocation fields or reasons', () => {
    for (const payload of [{}, { revision: 0 }, { revision: 1, title: 'leak' }]) {
      expect(() => parseRealtimeEvent(event('channel.updated', payload))).toThrow('Некорректное')
    }
    for (const payload of [{ lease_id: id }, { lease_id: id, reason: 'UNKNOWN' }, { lease_id: id, reason: 'KICK', body: 'secret' }]) {
      expect(() => parseRealtimeEvent(event('voice.lease_revoked', payload))).toThrow('Некорректное')
    }
  })

  it('rejects malformed permission invalidation hints', () => {
    for (const payload of [{ role: 'ADMINISTRATOR', revision: 1 }, { role: 'MEMBER', revision: 0 }, { role: 'MEMBER', revision: 1, login: 'secret' }]) {
      expect(() => parseRealtimeEvent(event('role.permissions.updated', payload))).toThrow('Некорректное')
    }
    expect(() => parseRealtimeEvent(event('auth.permissions.invalidated', { user_id: id }))).toThrow('Некорректное')
    expect(() => parseRealtimeEvent(event('member.profile.updated', { user_id: id, revision: 9, display_name: 'private' }))).toThrow('Некорректное')
  })
})
