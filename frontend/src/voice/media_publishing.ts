import type { VoiceRoom } from './livekit_gateway'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'

export type MicrophoneState = 'PUBLISHED' | 'MUTED' | 'LISTENER_PERMISSION_DENIED'
export type ScreenProfile = 'P720_30' | 'P720_60' | 'P1080_30' | 'P1080_60'
export interface AudioProcessingOptions {
  autoGainControl: boolean
  echoCancellation: boolean
  noiseSuppression: boolean
}

export interface ScreenShareOptions {
  audio: true
  resolution: { width: number; height: number; frameRate: number }
}

export interface MicrophonePublishOptions {
  audioPreset: { maxBitrate: number }
  forceStereo: false
}

export const defaultAudioProcessing: AudioProcessingOptions = { autoGainControl: true, echoCancellation: true, noiseSuppression: true }
const microphonePublishOptions: MicrophonePublishOptions = { audioPreset: { maxBitrate: 128_000 }, forceStereo: false }
const screenProfiles: Record<ScreenProfile, ScreenShareOptions> = {
  P720_30: { audio: true, resolution: { width: 1280, height: 720, frameRate: 30 } },
  P720_60: { audio: true, resolution: { width: 1280, height: 720, frameRate: 60 } },
  P1080_30: { audio: true, resolution: { width: 1920, height: 1080, frameRate: 30 } },
  P1080_60: { audio: true, resolution: { width: 1920, height: 1080, frameRate: 60 } },
}

export function microphoneConstraints(processing: AudioProcessingOptions = defaultAudioProcessing): MediaTrackConstraints {
  return { ...processing, channelCount: { ideal: 1 }, sampleRate: { ideal: 48_000 } }
}

export async function applyMicrophoneProcessing(room: VoiceRoom, processing: AudioProcessingOptions): Promise<void> {
  await room.applyMicrophoneProcessing?.(processing)
}

export async function setMicrophone(room: VoiceRoom, enabled: boolean, processing: AudioProcessingOptions = defaultAudioProcessing): Promise<MicrophoneState> {
  try {
    await room.localParticipant.setMicrophoneEnabled(enabled, microphoneConstraints(processing), microphonePublishOptions)
    return enabled ? 'PUBLISHED' : 'MUTED'
  } catch (cause) {
    if (enabled && cause instanceof Error && cause.name === 'NotAllowedError') return 'LISTENER_PERMISSION_DENIED'
    throw cause
  }
}

export async function readScreenShareDiagnostics(room: VoiceRoom): Promise<ScreenDiagnostics> {
  return room.readScreenDiagnostics ? room.readScreenDiagnostics() : unknownScreenDiagnostics()
}

export async function startScreenShare(room: VoiceRoom, profile: ScreenProfile): Promise<ScreenDiagnostics> {
  await room.localParticipant.setScreenShareEnabled(true, screenProfiles[profile])
  return readScreenShareDiagnostics(room)
}

export async function stopScreenShare(room: VoiceRoom): Promise<void> {
  await room.localParticipant.setScreenShareEnabled(false)
}
