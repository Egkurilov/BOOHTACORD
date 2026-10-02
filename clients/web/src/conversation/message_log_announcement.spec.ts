import { describe, expect, it } from 'vitest'

import { createMessageLogAnnouncer } from './message_log_announcement'

const message = (id: string, minute: number, authorId = 'other') => ({
  id, authorId, createdAt: `2026-09-25T10:${String(minute).padStart(2, '0')}:00Z`,
})
const displayName = (id: string) => id === 'other' ? 'Мика' : 'Я'

describe('screen-reader message log announcement', () => {
  it('is silent for initial history, older-page prepend and an edit, then announces only new remote rows', () => {
    const announce = createMessageLogAnnouncer()
    const initial = [message('m2', 2), message('m1', 1)]
    const base = { conversationId: 'text-1', loaded: true, active: true, ownId: 'self', displayName }
    expect(announce({ ...base, loaded: false, messages: [] })).toBeNull()
    expect(announce({ ...base, messages: initial })).toBeNull()
    expect(announce({ ...base, messages: [...initial, message('older', 0)] })).toBeNull()
    const edited = { ...initial[0], body: 'edited' }
    expect(announce({ ...base, messages: [edited, initial[1]] })).toBeNull()
    expect(announce({ ...base, messages: [message('m3', 3), ...initial] })).toBe('Новое сообщение от Мика.')
    expect(announce({ ...base, messages: [message('m3', 3), ...initial] })).toBeNull()
  })

  it('does not announce own acknowledgement or messages received while the tab is hidden', () => {
    const announce = createMessageLogAnnouncer()
    const base = { conversationId: 'dm-1', loaded: true, active: true, ownId: 'self', displayName }
    expect(announce({ ...base, messages: [message('m1', 1)] })).toBeNull()
    expect(announce({ ...base, messages: [message('own', 2, 'self'), message('m1', 1)] })).toBeNull()
    expect(announce({ ...base, active: false, messages: [message('hidden', 3), message('own', 2, 'self'), message('m1', 1)] })).toBeNull()
    expect(announce({ ...base, messages: [message('hidden', 3), message('own', 2, 'self'), message('m1', 1)] })).toBeNull()
  })

  it('announces a new message after an initially empty conversation, but not another conversation’s loaded page', () => {
    const announce = createMessageLogAnnouncer()
    const base = { loaded: true, active: true, ownId: 'self', displayName }
    expect(announce({ ...base, conversationId: 'text-1', messages: [] })).toBeNull()
    expect(announce({ ...base, conversationId: 'text-1', messages: [message('first', 1)] })).toBe('Новое сообщение от Мика.')
    expect(announce({ ...base, conversationId: 'text-2', messages: [message('history', 9)] })).toBeNull()
    expect(announce({ ...base, conversationId: 'text-2', messages: [message('new', 10), message('history', 9)] })).toBe('Новое сообщение от Мика.')
  })

  it('summarizes a batch and does not misannounce a replaced older page', () => {
    const announce = createMessageLogAnnouncer()
    const base = { conversationId: 'text-1', loaded: true, active: true, ownId: 'self', displayName }
    expect(announce({ ...base, messages: [message('m2', 2)] })).toBeNull()
    expect(announce({ ...base, messages: [message('m4', 4), message('m3', 3), message('m2', 2)] })).toBe('Новых сообщений: 2.')
    expect(announce({ ...base, messages: [message('older', 1)] })).toBeNull()
  })
})
