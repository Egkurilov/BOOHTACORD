import type { VoiceRoom } from './livekit_gateway'
import { browserProcessingConstraints, normalizeAudioProcessing, type AudioProcessingOptions } from './noise_suppression/types'
export type { AudioProcessingOptions } from './noise_suppression/types'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'

export type MicrophoneState = 'PUBLISHED' | 'MUTED' | 'LISTENER_PERMISSION_DENIED'
export type ScreenProfile =
  | 'P720_15' | 'P720_30' | 'P720_60'
  | 'P1080_15' | 'P1080_30' | 'P1080_60'
  | 'P1440_15' | 'P1440_30' | 'P1440_60'
export type ScreenResolution = 720 | 1080 | 1440
export type ScreenFrameRate = 15 | 30 | 60


export interface ScreenShareOptions {
  audio: true
  resolution: { width: number; height: number; frameRate: number }
}

export interface MicrophonePublishOptions {
  audioPreset: { maxBitrate: number; priority: 'high' }
  forceStereo: false
}

export interface ScreenSharePublishOptions {
  name: string
  degradationPreference: 'maintain-framerate'
  screenShareEncoding: { maxBitrate: number; maxFramerate: number; priority: 'medium' }
}

export const defaultAudioProcessing: AudioProcessingOptions = { autoGainControl: true, echoCancellation: true, noiseSuppressionMode: 'browser' }
export const adaptiveMediaRoomOptions = Object.freeze({ adaptiveStream: true, dynacast: true })
export const microphonePublishOptions: MicrophonePublishOptions = { audioPreset: { maxBitrate: 128_000, priority: 'high' }, forceStereo: false }
const screenBitrates: Record<ScreenResolution, Record<ScreenFrameRate, number>> = {
  720: { 15: 1_500_000, 30: 2_500_000, 60: 4_000_000 },
  1080: { 15: 2_500_000, 30: 5_000_000, 60: 8_000_000 },
  1440: { 15: 5_000_000, 30: 8_000_000, 60: 12_000_000 },
}
export function screenShareMaxBitrate(resolution: ScreenResolution, frameRate: ScreenFrameRate): number {
  return screenBitrates[resolution][frameRate]
}
// Capture at the highest supported ceiling so a later encoder change can
// raise FPS or resolution without asking the user to share the screen again.
const screenCaptureOptions: ScreenShareOptions = { audio: true, resolution: { width: 2560, height: 1440, frameRate: 60 } }

export function microphoneConstraints(processing: AudioProcessingOptions = defaultAudioProcessing): MediaTrackConstraints {
  return { ...browserProcessingConstraints(normalizeAudioProcessing(processing)), channelCount: { ideal: 1 }, sampleRate: { ideal: 48_000 } }
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

export async function startScreenShare(room: VoiceRoom, profile: ScreenProfile): Promise<ScreenDiagnostics> {
  const match = /^P(720|1080|1440)_(15|30|60)$/.exec(profile)
  if (!match) throw new Error('Некорректный профиль демонстрации.')
  const resolution = Number(match[1]) as ScreenResolution
  const frameRate = Number(match[2]) as ScreenFrameRate
  const screenSharePublishOptions: ScreenSharePublishOptions = {
    name: `screenshare-${resolution}p-${frameRate}fps`,
    degradationPreference: 'maintain-framerate',
    screenShareEncoding: {
      maxBitrate: screenShareMaxBitrate(resolution, frameRate),
      maxFramerate: frameRate,
      priority: 'medium',
    },
  }
  await room.localParticipant.setScreenShareEnabled(true, screenCaptureOptions, screenSharePublishOptions)
  return readScreenShareDiagnostics(room)
}

export async function stopScreenShare(room: VoiceRoom): Promise<void> {
  await room.localParticipant.setScreenShareEnabled(false)
}

export async function updateScreenShare(room: VoiceRoom, profile: ScreenProfile): Promise<ScreenDiagnostics> {
  if (!room.localParticipant.updateScreenShareProfile) throw new Error('Изменение качества во время трансляции недоступно.')
  await room.localParticipant.updateScreenShareProfile(profile)
  return readScreenShareDiagnostics(room)
}
