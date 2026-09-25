import { createPinia, setActivePinia } from 'pinia'
import { nextTick } from 'vue'
import { afterEach, describe, expect, it, vi } from 'vitest'

import { useTopologyStore } from '../channel/topology_store'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import type { RealtimeEvent } from '../realtime/realtime_client'
import type { NotificationRuntime } from './notification_delivery'
import { useNotificationStore } from './notification_store'

const event = { kind: 'direct_message.message_created', payload: { direct_message_id: 'dm-a' }, eventId: 'event-a', occurredAt: '2026-09-25T00:00:00Z' } satisfies RealtimeEvent

function runtime(): { port: NotificationRuntime; show: ReturnType<typeof vi.fn> } {
  const values = new Map<string, string>()
  const show = vi.fn()
  return { show, port: {
    permission: () => 'granted', requestPermission: async () => 'granted', show,
    storage: { getItem: (key) => values.get(key) ?? null, setItem: (key, value) => { values.set(key, value) } },
    lock: async (_key, action) => action(),
  } }
}

describe('workspace notification lifecycle', () => {
  afterEach(() => vi.unstubAllGlobals())

  it('updates title from protected counters and restores it on stop', async () => {
    vi.stubGlobal('document', { title: 'Voice Platform', visibilityState: 'hidden' })
    setActivePinia(createPinia())
    const topology = useTopologyStore()
    const directMessages = useDirectMessageStore()
    const store = useNotificationStore()
    store.start('account-a', runtime().port)
    topology.topology = { revision: 1, categories: [{ id: 'c', name: 'Общее', position: 0, channels: [{ id: 'text-a', name: 'Чат', kind: 'TEXT', position: 0, admissionClosed: false, unreadCount: 3, mentionCount: 0 }] }] }
    directMessages.directMessages = [{ id: 'dm-a', otherParticipantId: 'peer', otherParticipantDisplayName: 'Участник', createdAt: event.occurredAt, unreadCount: 2, mentionCount: 0 }]
    await nextTick()
    expect(document.title).toBe('(5) Voice Platform')
    store.stop()
    expect(document.title).toBe('Voice Platform')
  })

  it('alerts only for a new unread count while hidden', async () => {
    vi.stubGlobal('document', { title: 'Voice Platform', visibilityState: 'hidden' })
    setActivePinia(createPinia())
    const directMessages = useDirectMessageStore()
    directMessages.directMessages = [{ id: 'dm-a', otherParticipantId: 'peer', otherParticipantDisplayName: 'Участник', createdAt: event.occurredAt, unreadCount: 1, mentionCount: 0 }]
    const value = runtime()
    const store = useNotificationStore()
    store.start('account-a', value.port)
    await store.enable()
    const before = store.capture(event)
    directMessages.directMessages = [{ ...directMessages.directMessages[0]!, unreadCount: 2 }]
    await store.deliver(event, before)
    expect(value.show).toHaveBeenCalledOnce()
    await store.deliver({ ...event, eventId: 'event-b' }, 2)
    expect(value.show).toHaveBeenCalledOnce()
    vi.stubGlobal('document', { title: document.title, visibilityState: 'visible' })
    await store.deliver({ ...event, eventId: 'event-c' }, 1)
    expect(value.show).toHaveBeenCalledOnce()
    store.stop()
  })

  it('alerts for the first incoming message when its DM appears after refresh', async () => {
    vi.stubGlobal('document', { title: 'Voice Platform', visibilityState: 'hidden' })
    setActivePinia(createPinia())
    const directMessages = useDirectMessageStore()
    const value = runtime()
    const store = useNotificationStore()
    store.start('account-a', value.port)
    await store.enable()

    const before = store.capture(event)
    expect(before).toBe(0)
    directMessages.directMessages = [{ id: 'dm-a', otherParticipantId: 'peer', otherParticipantDisplayName: 'Участник', createdAt: event.occurredAt, unreadCount: 1, mentionCount: 0 }]
    await store.deliver(event, before)
    expect(value.show).toHaveBeenCalledExactlyOnceWith('Voice Platform', { body: 'Новое личное сообщение.', tag: 'event-a' })

    const unrelated = { ...event, eventId: 'event-b', payload: { direct_message_id: 'dm-b' } }
    await store.deliver(unrelated, store.capture(unrelated))
    expect(value.show).toHaveBeenCalledOnce()
    store.stop()
  })
})
