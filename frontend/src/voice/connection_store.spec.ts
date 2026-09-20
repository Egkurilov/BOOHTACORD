import { createPinia, setActivePinia } from 'pinia'
import { isProxy } from 'vue'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const fixture = vi.hoisted(() => {
  const room: Record<string, unknown> = {}
  room.self = room
  return {
    join: vi.fn(),
    room,
  }
})

vi.mock('../identity/current_session', () => ({
  loadCurrentSession: vi.fn().mockResolvedValue({ accountId: 'account-1' }),
}))

vi.mock('./voice_session', () => ({
  VoiceSession: class {
    audioProcessing = { diagnostics: { supported: false } }
    screen = {}
    join = fixture.join
    participantCards = () => null
    remoteVoices = () => null
    screenViewer = () => null
    setAudioProcessing = vi.fn().mockResolvedValue(undefined)
    setConnectionObserver = vi.fn()
  },
}))

import { useVoiceConnectionStore } from './connection_store'

describe('voice connection store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    fixture.join.mockReset()
    fixture.join.mockResolvedValue({
      channelId: 'channel-1',
      leaseId: 'lease-1',
      microphone: 'PUBLISHED',
      room: fixture.room,
      screenProfile: null,
    })
  })

  it('does not make the cyclic LiveKit room reactive after joining', async () => {
    const store = useVoiceConnectionStore()

    await store.join('channel-1')

    expect(store.active?.room).toBe(fixture.room)
    expect(isProxy(store.active?.room)).toBe(false)
  })
})
