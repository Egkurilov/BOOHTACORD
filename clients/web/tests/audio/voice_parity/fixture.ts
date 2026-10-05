import { LocalAudioTrack, Room, RoomEvent, Track } from 'livekit-client'
import { voiceAudioProfiles } from '../../../src/voice/audio_profile/generated'
import { publishOptions, type VoiceAudioProfile } from '../../../src/voice/audio_profile/profile'
import { bindVoiceAudioDiagnostics } from '../../../src/voice/audio_diagnostics/bind'
import type { AudioSample } from '../../../src/voice/audio_diagnostics/model'
import type { VoiceRoom } from '../../../src/voice/livekit_gateway'
let room: Room | undefined, adapter: VoiceRoom | undefined
let track: LocalAudioTrack | undefined, context: AudioContext | undefined
let oscillator: OscillatorNode | undefined, gain: GainNode | undefined
let element: HTMLMediaElement | undefined, role: 'sender' | 'receiver'
async function connect(selectedRole: 'sender' | 'receiver', profile: VoiceAudioProfile) {
  role = selectedRole
  const response = await fetch(`/tests/audio/livekit-token?role=${role}`, { cache: 'no-store' })
  if (!response.ok) throw new Error('Isolated SFU credential unavailable')
  const credentials = await response.json()
  room = new Room()
  adapter = { readAudioProcessingSettings: () => track?.mediaStreamTrack.getSettings() } as unknown as VoiceRoom
  bindVoiceAudioDiagnostics(adapter, room, profile)
  room.on(RoomEvent.TrackSubscribed, remote => {
    if (remote.kind !== Track.Kind.Audio) return
    element = remote.attach(); element.muted = true
    document.body.append(element); void element.play()
  })
  await room.connect(credentials.url, credentials.token)
}
const wait = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))
export const voiceParity = {
  async receiver() { await connect('receiver', voiceAudioProfiles[0]) },
  async sender(id: string, red?: boolean) {
    const profile = voiceAudioProfiles.find(profile => profile.id === id)
    if (!profile) throw new Error('Unknown profile')
    await connect('sender', profile)
    context = new AudioContext({ sampleRate: 48000 }); await context.resume()
    oscillator = context.createOscillator(); oscillator.frequency.value = 440
    gain = context.createGain(); gain.gain.value = 0.2
    const output = context.createMediaStreamDestination(); output.channelCount = 1
    oscillator.connect(gain); gain.connect(output); oscillator.start()
    track = new LocalAudioTrack(output.stream.getAudioTracks()[0], { sampleRate: 48000, channelCount: 1 }, true, context)
    await room!.localParticipant.publishTrack(track, { source: Track.Source.Microphone, ...publishOptions(profile), ...(red === undefined ? {} : { red }) })
    await adapter!.readVoiceAudioDiagnostics!()
    return { senderCap: track.sender?.getParameters().encodings[0]?.maxBitrate ?? null, contextRate: context.sampleRate }
  },
  async sample(count: number) {
    const samples: AudioSample[] = []
    let profile = '', clockRate: number | null = null, codec: string | null = null
    for (let index = 0; index < count; index++) {
      await wait(2000)
      const snapshot = await adapter!.readVoiceAudioDiagnostics!()
      profile = snapshot.profile
      for (const sample of snapshot.samples.filter(sample => sample.direction === role)) {
        clockRate = sample.clockRate; codec = sample.codec
        if (sample.bitrateBps !== null && sample.intervalMs !== null) samples.push(sample)
      }
    }
    const duration = samples.reduce((sum, sample) => sum + sample.intervalMs!, 0)
    return { profile, codec, clockRate, measurements: samples.length,
      meanBitrateBps: duration > 0 ? samples.reduce((sum, sample) => sum + sample.bitrateBps! * sample.intervalMs!, 0) / duration : null,
      packets: samples.reduce((sum, sample) => sum + (sample.packets ?? 0), 0),
      red: samples.map(sample => sample.red), intervalBitrates: samples.map(sample => sample.bitrateBps) }
  },
  async silence() { gain!.gain.setValueAtTime(0, context!.currentTime); await wait(6000); await adapter!.readVoiceAudioDiagnostics!() },
  async stop() {
    track?.stop(); oscillator?.stop(); gain?.disconnect(); element?.remove()
    await room?.disconnect(); await context?.close()
    room = undefined; adapter = undefined; track = undefined; context = undefined
    oscillator = undefined; gain = undefined; element = undefined
  },
}
;(window as unknown as { voiceParity: typeof voiceParity }).voiceParity = voiceParity
