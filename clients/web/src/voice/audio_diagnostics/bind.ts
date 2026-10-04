import { Track, RoomEvent, type Room } from 'livekit-client'
import type { VoiceRoom } from '../livekit_gateway'
import type { VoiceAudioProfile } from '../audio_profile/profile'
import { statNumber, type AudioSample, type RawAudioStat } from './model'
import { AudioStatsReader } from './stats'
export function bindVoiceAudioDiagnostics(room: VoiceRoom, liveKit: Room, profile: VoiceAudioProfile): void {
  let reader = new AudioStatsReader()
  const identities = new WeakMap<object, { endpoint: object; scope: string }>()
  let sequence = 0, epoch = 0
  const reset = () => { epoch++; reader = new AudioStatsReader() }
  liveKit.on(RoomEvent.Reconnecting, reset)
  liveKit.on(RoomEvent.Reconnected, reset)
  liveKit.on(RoomEvent.Disconnected, reset)
  room.readVoiceAudioDiagnostics = async () => {
    const samples: AudioSample[] = []
    const generation = epoch
    const currentReader = reader
    const scopes = new Set<string>()
    const read = async (track: MediaStreamTrack | undefined, endpoint: RTCRtpSender | RTCRtpReceiver | undefined, direction: 'sender' | 'receiver') => {
      if (!endpoint || !track) return
      let identity = identities.get(track)
      if (!identity || identity.endpoint !== endpoint) { identity = { endpoint, scope: String(++sequence) }; identities.set(track, identity) }
      const scope = identity.scope
      scopes.add(scope)
      let timer: ReturnType<typeof setTimeout> | undefined
      try {
        const report = await Promise.race([endpoint.getStats(), new Promise<never>((_, reject) => {
          timer = setTimeout(() => reject(new Error('Audio stats unavailable')), 1500)
        })])
        if (epoch === generation) samples.push(...currentReader.read(scope, direction, Array.from(report.values()) as RawAudioStat[], performance.now()))
      } catch { /* Unsupported stats stay absent; never substitute the cap. */ }
      finally { clearTimeout(timer) }
    }
    const local = liveKit.localParticipant.getTrackPublication(Track.Source.Microphone)?.audioTrack
    const pending = [read(local?.mediaStreamTrack, local?.sender, 'sender')]
    for (const participant of liveKit.remoteParticipants.values()) {
      for (const publication of participant.audioTrackPublications.values()) {
        if (publication.source === Track.Source.Microphone && publication.isSubscribed) {
          const track = publication.audioTrack
          pending.push(read(track?.mediaStreamTrack, track && 'receiver' in track ? track.receiver : undefined, 'receiver'))
        }
      }
    }
    await Promise.all(pending)
    if (generation !== epoch) throw new Error('Audio stats session changed')
    currentReader.retain(scopes)
    const capture = room.readAudioProcessingSettings?.()
    return { profile: profile.id, capBps: profile.maxBitrate, samples,
      capture: { sampleRate: statNumber(capture?.sampleRate), channels: statNumber(capture?.channelCount),
        agc: capture?.autoGainControl ?? null, aec: capture?.echoCancellation ?? null, ns: capture?.noiseSuppression ?? null } }
  }
}
