import type { VoiceRoom } from './livekit_gateway'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'

export type MicrophoneState = 'PUBLISHED' | 'MUTED' | 'LISTENER_PERMISSION_DENIED'
export type ScreenProfile =
  | 'P720_15' | 'P720_30' | 'P720_60'
  | 'P1080_15' | 'P1080_30' | 'P1080_60'
  | 'P1440_15' | 'P1440_30' | 'P1440_60'
export type ScreenResolution = 720 | 1080 | 1440
export type ScreenFrameRate = 15 | 30 | 60
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
  audioPreset: { maxBitrate: number; priority: 'high' }
  forceStereo: false
}

export interface ScreenSharePublishOptions {
  name: string
  degradationPreference: 'maintain-framerate'
  screenShareEncoding: { maxBitrate: number; maxFramerate: number; priority: 'medium' }
}

export const defaultAudioProcessing: AudioProcessingOptions = { autoGainControl: true, echoCancellation: true, noiseSuppression: true }
export const adaptiveMediaRoomOptions = Object.freeze({ adaptiveStream: true, dynacast: true })
const microphonePublishOptions: MicrophonePublishOptions = { audioPreset: { maxBitrate: 128_000, priority: 'high' }, forceStereo: false }
const screenResolutions = { 720: 1280, 1080: 1920, 1440: 2560 } as const
const screenBitrates: Record<ScreenResolution, Record<ScreenFrameRate, number>> = {
  720: { 15: 1_500_000, 30: 2_500_000, 60: 4_000_000 },
  1080: { 15: 2_500_000, 30: 5_000_000, 60: 8_000_000 },
  1440: { 15: 5_000_000, 30: 8_000_000, 60: 12_000_000 },
}
export function screenShareMaxBitrate(resolution: ScreenResolution, frameRate: ScreenFrameRate): number {
  return screenBitrates[resolution][frameRate]
}
const screenProfiles = Object.fromEntries(
  ([720, 1080, 1440] as const).flatMap((height) =>
    ([15, 30, 60] as const).map((frameRate) => [
      `P${height}_${frameRate}`,
      { audio: true, resolution: { width: screenResolutions[height], height, frameRate } },
    ]),
  ),
) as Record<ScreenProfile, ScreenShareOptions>

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
  const capture = screenProfiles[profile]
  const height = capture.resolution.height
  const resolution = height as ScreenResolution
  const frameRate = capture.resolution.frameRate as ScreenFrameRate
  const screenSharePublishOptions: ScreenSharePublishOptions = {
    name: `screenshare-${height}p-${frameRate}fps`,
    degradationPreference: 'maintain-framerate',
    screenShareEncoding: {
      maxBitrate: screenShareMaxBitrate(resolution, frameRate),
      maxFramerate: frameRate,
      priority: 'medium',
    },
  }
  await room.localParticipant.setScreenShareEnabled(true, capture, screenSharePublishOptions)
  return readScreenShareDiagnostics(room)
}

export async function stopScreenShare(room: VoiceRoom): Promise<void> {
  await room.localParticipant.setScreenShareEnabled(false)
}
