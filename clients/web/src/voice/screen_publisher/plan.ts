import { VideoPreset, type ScreenShareCaptureOptions, type TrackPublishOptions } from 'livekit-client'
import { screenProfile, type ScreenProfile } from '../screen_profile/policy'
import { browserScreenCodecCapabilities, selectScreenVideoCodec, type ScreenCodecCapability } from './codec_policy'

export function screenCapturePlan(profile: ScreenProfile): ScreenShareCaptureOptions {
  const target = screenProfile(profile)
  return { audio: true, contentHint: target.frameRate === 60 ? 'motion' : 'text',
    resolution: { width: target.width, height: target.height, frameRate: target.frameRate } }
}

function boundedSimulcastEnabled(): boolean {
  return import.meta.env.VITE_SCREEN_SHARE_BOUNDED_SIMULCAST === 'true'
}

export function screenPublishPlan(
  profile: ScreenProfile,
  capabilities: readonly ScreenCodecCapability[] | null | undefined = browserScreenCodecCapabilities(),
  simulcastEnabled = boundedSimulcastEnabled(),
): TrackPublishOptions {
  const target = screenProfile(profile)
  const decision = selectScreenVideoCodec(capabilities)
  if (decision.outcome === 'unsupported') {
    throw new Error('No supported screen-sharing video codec is advertised by browser capabilities.')
  }
  const simulcast = simulcastEnabled
    ? { simulcast: true as const, screenShareSimulcastLayers: [lowLayer(target)] }
    : { simulcast: false as const }
  return { name: `screenshare-${target.height}p-${target.frameRate}fps`, videoCodec: decision.codec, ...simulcast,
    degradationPreference: target.frameRate === 60 ? 'maintain-framerate' : 'maintain-resolution',
    screenShareEncoding: { maxBitrate: target.bitrate, maxFramerate: target.frameRate, priority: 'medium' } }
}

function lowLayer(target: ReturnType<typeof screenProfile>): VideoPreset {
  const bitrate = Math.max(150_000, Math.floor(target.bitrate / (4 * (target.frameRate / 15))))
  return new VideoPreset(Math.floor(target.width / 2), Math.floor(target.height / 2), bitrate, 15, 'medium')
}
