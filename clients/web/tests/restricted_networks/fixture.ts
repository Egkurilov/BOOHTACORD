import { LocalAudioTrack, Room, RoomEvent, Track, setLogLevel } from 'livekit-client'
import type { VoiceRoom } from '../../src/voice/livekit_gateway'
import { bindNetworkDiagnostics } from '../../src/voice/network_diagnostics/bind'
import { exportNetworkDiagnostics } from '../../src/voice/network_diagnostics/export'
import { publishOptions, selectedVoiceAudioProfile } from '../../src/voice/audio_profile/profile'
setLogLevel('silent')
let room: Room | undefined, adapter: VoiceRoom | undefined
let context: AudioContext | undefined, tone: OscillatorNode | undefined, track: LocalAudioTrack | undefined
let element: HTMLMediaElement | undefined
const fixture = {
  async connect(role: 'sender' | 'receiver') {
    const response = await fetch(`/network-token?role=${role}`, { cache: 'no-store' })
    if (!response.ok) throw new Error('Isolated credential unavailable')
    const credential = await response.json()
    room = new Room(); adapter = room as unknown as VoiceRoom
    bindNetworkDiagnostics(adapter, room)
    room.on(RoomEvent.TrackSubscribed, remote => {
      if (remote.kind !== Track.Kind.Audio) return
      element = remote.attach(); element.muted = true; document.body.append(element); void element.play()
    })
    try { await room.connect(credential.url, credential.token, { maxRetries: 0, websocketTimeout: 5000, peerConnectionTimeout: 12000 }); return true }
    catch { return false }
  },
  async publish() {
    context = new AudioContext({ sampleRate: 48000 }); await context.resume()
    tone = context.createOscillator(); tone.frequency.value = 440
    const gain = context.createGain(); gain.gain.value = 0.2
    const output = context.createMediaStreamDestination(); output.channelCount = 1
    tone.connect(gain); gain.connect(output); tone.start()
    track = new LocalAudioTrack(output.stream.getAudioTracks()[0], { sampleRate: 48000, channelCount: 1 }, true, context)
    await room!.localParticipant.publishTrack(track, { source: Track.Source.Microphone, ...publishOptions(selectedVoiceAudioProfile()) })
  },
  async read() { return JSON.parse(exportNetworkDiagnostics(await adapter!.readNetworkDiagnostics!())) },
  async stop() { track?.stop(); tone?.stop(); element?.remove(); await room?.disconnect(); await context?.close() },
}
;(window as unknown as { restrictedNetwork: typeof fixture }).restrictedNetwork = fixture
