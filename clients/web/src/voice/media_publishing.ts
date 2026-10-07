import type { VoiceRoom } from './livekit_gateway'
import { publishOptions } from './audio_profile/profile'
import { voiceAudioProfiles } from './audio_profile/generated'
import { browserProcessingConstraints, normalizeAudioProcessing, type AudioProcessingOptions } from './noise_suppression/types'
export type { AudioProcessingOptions } from './noise_suppression/types'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'
export { screenShareMaxBitrate, type ScreenProfile, type ScreenResolution, type ScreenFrameRate } from './screen_profile/policy'

export type MicrophoneState = 'PUBLISHED' | 'MUTED' | 'LISTENER_PERMISSION_DENIED'


export interface MicrophonePublishOptions {
  audioPreset: { maxBitrate: number; priority: 'high' }
  forceStereo: false
  dtx: true
  red: true
}

export const defaultAudioProcessing: AudioProcessingOptions = { autoGainControl: true, echoCancellation: true, noiseSuppressionMode: 'browser' }
export const adaptiveMediaRoomOptions = Object.freeze({ adaptiveStream: true, dynacast: true })
export const microphonePublishOptions: MicrophonePublishOptions = publishOptions(voiceAudioProfiles[0])

export function microphoneConstraints(processing: AudioProcessingOptions = defaultAudioProcessing): MediaTrackConstraints {
  return { ...browserProcessingConstraints(normalizeAudioProcessing(processing)), channelCount: { ideal: voiceAudioProfiles[0].captureChannels }, sampleRate: { ideal: voiceAudioProfiles[0].sampleRate } }
}

export async function applyMicrophoneProcessing(room: VoiceRoom, processing: AudioProcessingOptions): Promise<void> {
  await room.applyMicrophoneProcessing?.(processing)
}

export async function setMicrophone(room: VoiceRoom, enabled: boolean, processing: AudioProcessingOptions = defaultAudioProcessing): Promise<MicrophoneState> {
  try {
    if (room.setMicrophone) await room.setMicrophone(enabled, normalizeAudioProcessing(processing))
    else await room.localParticipant.setMicrophoneEnabled(enabled, microphoneConstraints(processing), microphonePublishOptions)
    return enabled ? 'PUBLISHED' : 'MUTED'
  } catch (cause) {
    if (enabled && cause instanceof Error && cause.name === 'NotAllowedError') return 'LISTENER_PERMISSION_DENIED'
    throw cause
  }
}

export async function readScreenShareDiagnostics(room: VoiceRoom): Promise<ScreenDiagnostics> {
  return room.readScreenDiagnostics ? room.readScreenDiagnostics() : unknownScreenDiagnostics()
}
