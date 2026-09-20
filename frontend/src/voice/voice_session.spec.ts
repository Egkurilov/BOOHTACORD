import { describe, expect, it, vi } from 'vitest'

import { VoiceSession, type VoiceAdmission } from './voice_session'

function admission(): VoiceAdmission {
  return {
    acquire: vi.fn().mockResolvedValue({ id: 'lease-1', channelId: 'voice-1', transferred: false }),
    credential: vi.fn().mockResolvedValue({ url: 'wss://rtc.example', token: 'temporary', expiresAt: '2026-09-17T12:00:00Z' }),
    release: vi.fn().mockResolvedValue(undefined),
  }
}

describe('voice session', () => {
  it('marks a room active only after a lease, credential and room join succeed', async () => {
    const api = admission()
    const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn() }
    const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'PUBLISHED' }))

    await expect(session.join('voice-1')).resolves.toMatchObject({ leaseId: 'lease-1', channelId: 'voice-1' })
    expect(api.acquire).toHaveBeenCalledWith('voice-1', false)
    expect(api.credential).toHaveBeenCalledWith('lease-1')
  })

  it('releases a lease if later credential or media work fails', async () => {
    const api = admission()
    vi.mocked(api.credential).mockRejectedValue(new Error('expired'))
    const session = new VoiceSession(api)

    await expect(session.join('voice-1')).rejects.toThrow('expired')
    expect(api.release).toHaveBeenCalledWith('lease-1')
    expect(session.active).toBeNull()
  })
})

it('reports SDK reconnect state and clears a permanently disconnected lease', async () => {
  const api = admission()
  const callbacks: Record<string, () => void> = {}
  const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn((event: string, callback: () => void) => { callbacks[event] = callback }) }
  const observer = { reconnecting: vi.fn(), reconnected: vi.fn(), disconnected: vi.fn() }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))
  session.setConnectionObserver(observer)

  await session.join('voice-1')
  callbacks.reconnecting()
  callbacks.reconnected()
  callbacks.disconnected()
  await vi.waitFor(() => expect(observer.disconnected).toHaveBeenCalledOnce())

  expect(api.release).toHaveBeenCalledWith('lease-1')
  expect(session.active).toBeNull()
})

it('deafens remote media, forces an active microphone off, then restores its former state', async () => {
  const api = admission()
  const room = {
    disconnect: vi.fn().mockResolvedValue(undefined),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) },
    on: vi.fn(),
    setDeafened: vi.fn(),
  }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'PUBLISHED' }))

  await session.join('voice-1')
  await session.setDeafened(true)
  await session.setDeafened(false)

  expect(room.setDeafened).toHaveBeenNthCalledWith(1, true)
  expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenNthCalledWith(1, false, expect.any(Object), expect.any(Object))
  expect(room.setDeafened).toHaveBeenNthCalledWith(2, false)
  expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenNthCalledWith(2, true, expect.any(Object), expect.any(Object))
})

it('does not enable a microphone that was muted before deafen', async () => {
  const api = admission()
  const room = {
    disconnect: vi.fn().mockResolvedValue(undefined),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) },
    on: vi.fn(),
    setDeafened: vi.fn(),
  }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))

  await session.join('voice-1')
  await session.setDeafened(true)
  await session.setDeafened(false)

  expect(room.setDeafened).toHaveBeenNthCalledWith(1, true)
  expect(room.setDeafened).toHaveBeenNthCalledWith(2, false)
  expect(room.localParticipant.setMicrophoneEnabled).not.toHaveBeenCalled()
})

it('updates an active local track and carries processing preferences through mute and deafen', async () => {
  const api = admission()
  const processing = { autoGainControl: false, echoCancellation: false, noiseSuppression: true }
  const room = {
    applyMicrophoneProcessing: vi.fn().mockResolvedValue(undefined),
    disconnect: vi.fn().mockResolvedValue(undefined),
    localParticipant: { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) },
    on: vi.fn(),
    setDeafened: vi.fn(),
  }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'PUBLISHED' }))

  await session.join('voice-1')
  await session.setAudioProcessing(processing)
  await session.setMicrophoneMuted(true)
  await session.setMicrophoneMuted(false)
  await session.setDeafened(true)
  await session.setDeafened(false)

  expect(room.applyMicrophoneProcessing).toHaveBeenCalledWith(processing)
  expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenNthCalledWith(2, true, expect.objectContaining(processing), expect.any(Object))
  expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenNthCalledWith(4, true, expect.objectContaining(processing), expect.any(Object))
})

it('exposes only the room-owned remote voice playback controller to UI controls', async () => {
  const api = admission()
  const remoteVoices = { cards: () => [] }
  const participantCards = { cards: () => [] }
  const room = { disconnect: vi.fn().mockResolvedValue(undefined), on: vi.fn(), participantCards, remoteVoices }
  const session = new VoiceSession(api, async () => ({ room: room as never, microphone: 'MUTED' }))

  await session.join('voice-1')

  expect(session.remoteVoices()).toBe(remoteVoices)
  expect(session.participantCards()).toBe(participantCards)
})
