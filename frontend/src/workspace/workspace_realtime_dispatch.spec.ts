import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import type { RealtimeEvent } from '../realtime/realtime_client'
import { useVoiceNavigationStore } from '../voice/navigation_store'
import { createWorkspaceRealtime } from './workspace_realtime'

const directID = '11111111-1111-4111-8111-111111111111'
const messageID = '22222222-2222-4222-8222-222222222222'
const leaseID = '33333333-3333-4333-8333-333333333333'

function hint(kind: RealtimeEvent['kind'], payload: Record<string, unknown>): RealtimeEvent {
  return { kind, payload, eventId: '44444444-4444-4444-8444-444444444444', occurredAt: '2026-09-25T00:00:00Z' }
}

function fixture() {
  const stores = {
    topology: { refresh: vi.fn(async () => {}), error: null },
    messages: { channelId: null, refresh: vi.fn(async () => {}), error: null },
    directMessages: { directMessageId: directID, refreshNavigation: vi.fn(async () => {}), refreshHistory: vi.fn(async () => {}), error: null },
  }
  const voice = { active: { leaseId: leaseID }, state: 'CONNECTED', revokeLease: vi.fn(async () => true) }
  let deliver!: (event: RealtimeEvent) => void | Promise<void>
  const realtime = { connect: vi.fn((handler) => { deliver = handler }), disconnect: vi.fn() }
  const presence = { acceptRealtimeEvent: vi.fn(() => false) }
  createWorkspaceRealtime(stores, realtime as never, presence as never, voice as never, 'account-1', vi.fn()).start()
  return { stores, voice, deliver: (event: RealtimeEvent) => deliver(event) }
}

describe('workspace typed realtime dispatch', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it.each(['direct_message.message_created', 'direct_message.message_updated', 'direct_message.message_deleted'] as const)('refreshes only the addressed DM on %s', async (kind) => {
    const value = fixture()
    await value.deliver(hint(kind, { direct_message_id: directID, message_id: messageID, ...(kind === 'direct_message.message_created' ? {} : { revision: 2 }) }))
    expect(value.stores.directMessages.refreshNavigation).toHaveBeenCalledOnce()
    expect(value.stores.directMessages.refreshHistory).toHaveBeenCalledOnce()
    expect(value.stores.topology.refresh).not.toHaveBeenCalled()
  })

  it('refreshes topology for channel.updated without replacing active DM history', async () => {
    const value = fixture()
    await value.deliver(hint('channel.updated', { revision: 7 }))
    expect(value.stores.topology.refresh).toHaveBeenCalledOnce()
    expect(value.stores.directMessages.refreshHistory).not.toHaveBeenCalled()
  })

  it('applies only the connected lease revocation and clears voice navigation', async () => {
    const value = fixture()
    const navigation = useVoiceNavigationStore()
    navigation.confirmVoiceConnected('voice-1')
    await value.deliver(hint('voice.lease_revoked', { lease_id: '55555555-5555-4555-8555-555555555555', reason: 'KICK' }))
    expect(value.voice.revokeLease).not.toHaveBeenCalled()
    expect(navigation.activeVoiceChannelId).toBe('voice-1')
    await value.deliver(hint('voice.lease_revoked', { lease_id: leaseID, reason: 'CHANNEL_CLOSED' }))
    expect(value.voice.revokeLease).toHaveBeenCalledWith(leaseID, 'CHANNEL_CLOSED')
    expect(navigation.activeVoiceChannelId).toBeNull()
  })
})
