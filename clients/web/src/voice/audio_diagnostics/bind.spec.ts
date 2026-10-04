import { expect, it, vi } from 'vitest'
import { RoomEvent, Track, type Room } from 'livekit-client'
import type { VoiceRoom } from '../livekit_gateway'
import { voiceAudioProfiles } from '../audio_profile/generated'
import { bindVoiceAudioDiagnostics } from './bind'
it('scopes stats to microphone publications and resets on track replacement and reconnect', async () => {
  const callbacks = new Map<string, () => void>()
  let bytes = 100, timestamp = 1
  const getStats = vi.fn(async () => new Map([['rtp', { id: 'rtp', type: 'outbound-rtp', kind: 'audio', bytesSent: bytes, timestamp }]]))
  const sender = { getStats }
  const mic = { mediaStreamTrack: {}, sender }
  const screen = { mediaStreamTrack: {}, receiver: { getStats: vi.fn() } }
  const receiver = { getStats: vi.fn(async () => new Map()) }
  const remote = { mediaStreamTrack: {}, receiver }
  const room = { readAudioProcessingSettings: () => ({ sampleRate: 44100, channelCount: 1 }) } as VoiceRoom
  const sdk = {
    on: (event: string, listener: () => void) => callbacks.set(event, listener),
    localParticipant: { getTrackPublication: () => ({ audioTrack: mic }) },
    remoteParticipants: new Map([['peer', { audioTrackPublications: new Map([
      ['screen', { source: Track.Source.ScreenShareAudio, isSubscribed: true, audioTrack: screen }],
      ['mic', { source: Track.Source.Microphone, isSubscribed: true, audioTrack: remote }],
    ]) }]]),
  } as unknown as Room
  bindVoiceAudioDiagnostics(room, sdk, voiceAudioProfiles[0])
  const first = await room.readVoiceAudioDiagnostics!()
  expect(first.capture.sampleRate).toBe(44100)
  expect(screen.receiver.getStats).not.toHaveBeenCalled()
  expect(receiver.getStats).toHaveBeenCalledTimes(1)
  bytes = 200; timestamp++
  mic.mediaStreamTrack = {}
  expect((await room.readVoiceAudioDiagnostics!()).samples[0]!.bitrateBps).toBeNull()
  callbacks.get(RoomEvent.Reconnecting)!()
  callbacks.get(RoomEvent.Reconnected)!()
  bytes = 300; timestamp++
  expect((await room.readVoiceAudioDiagnostics!()).samples[0]!.bitrateBps).toBeNull()
})
