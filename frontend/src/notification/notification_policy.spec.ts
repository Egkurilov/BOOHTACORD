import { describe, expect, it } from 'vitest'

import { notificationCandidate, notificationTitle, unreadTotal } from './notification_policy'

const topology = { categories: [{ channels: [
  { id: 'text-a', kind: 'TEXT', unreadCount: 3, mentionCount: 1 },
  { id: 'voice-a', kind: 'VOICE' },
] }] }
const directMessages = [{ id: 'dm-a', unreadCount: 2, mentionCount: 1 }]

describe('notification privacy policy', () => {
  it('uses caller-local unread totals for the title badge', () => {
    expect(unreadTotal(topology, directMessages)).toBe(5)
    expect(notificationTitle('Voice Platform', 5)).toBe('(5) Voice Platform')
    expect(notificationTitle('Voice Platform', 101)).toBe('(99+) Voice Platform')
    expect(notificationTitle('Voice Platform', 0)).toBe('Voice Platform')
  })

  it('returns only generic text for unread addressed create events', () => {
    const dm = { kind: 'direct_message.message_created', payload: { direct_message_id: 'dm-a', body: 'секретный текст' } }
    expect(notificationCandidate(dm, topology, directMessages)).toBe('Новое личное сообщение.')
    expect(notificationCandidate({ kind: 'message.created', payload: { channel_id: 'text-a', body: 'секретный текст' } }, topology, directMessages)).toBe('Новое сообщение в канале.')
    expect(notificationCandidate(dm, topology, directMessages)).not.toContain('секретный')
  })

  it('ignores own/read, unrelated, edit and delete events', () => {
    expect(notificationCandidate({ kind: 'message.created', payload: { channel_id: 'text-a' } }, topology, directMessages, 3)).toBeNull()
    expect(notificationCandidate({ kind: 'direct_message.message_created', payload: { direct_message_id: 'dm-b' } }, topology, directMessages)).toBeNull()
    expect(notificationCandidate({ kind: 'message.updated', payload: { channel_id: 'text-a' } }, topology, directMessages)).toBeNull()
    expect(notificationCandidate({ kind: 'message.created', payload: { channel_id: 'text-b' } }, topology, directMessages)).toBeNull()
  })
})
