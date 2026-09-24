import { createPinia, setActivePinia } from 'pinia'
import { isProxy } from 'vue'
import { beforeEach, describe, expect, it, vi } from 'vitest'

const fixture = vi.hoisted(() => {
  const room: Record<string, unknown> = {}
  room.self = room
  return {
    join: vi.fn(),
    leave: vi.fn(),
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
    leave = fixture.leave
    get active() { return null }
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
    fixture.leave.mockReset()
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

  it('keeps a listener-only join muted in the connected store', async () => {
    fixture.join.mockResolvedValueOnce({ channelId: 'channel-1', leaseId: 'lease-1', microphone: 'MUTED', room: fixture.room, screenProfile: null })
    const store = useVoiceConnectionStore()

    await store.join('channel-1', false, 'listener')

    expect(fixture.join).toHaveBeenCalledWith('channel-1', false, 'listener')
    expect(store.state).toBe('LISTENER')
    expect(store.microphoneMuted).toBe(true)
  })

  it('clears local active media state when release fails after the room disconnected', async () => {
    const store = useVoiceConnectionStore()
    await store.join('channel-1')
    fixture.leave.mockRejectedValueOnce(new Error('release failed'))

    await store.leave()

    expect(store.active).toBeNull()
    expect(store.state).toBe('IDLE')
  })
})
