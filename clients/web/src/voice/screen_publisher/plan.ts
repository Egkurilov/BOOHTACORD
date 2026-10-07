import { VideoPreset, type ScreenShareCaptureOptions, type TrackPublishOptions } from 'livekit-client'
import { screenProfile, type ScreenProfile } from '../screen_profile/policy'

export function screenCapturePlan(profile: ScreenProfile): ScreenShareCaptureOptions {
  const target = screenProfile(profile)
  return { audio: true, contentHint: target.frameRate === 60 ? 'motion' : 'text',
    resolution: { width: target.width, height: target.height, frameRate: target.frameRate } }
}

export function screenPublishPlan(profile: ScreenProfile): TrackPublishOptions {
  const target = screenProfile(profile)
  const lowBitrate = Math.max(150_000, Math.floor(target.bitrate / (4 * (target.frameRate / 15))))
  const lowLayer = new VideoPreset(Math.floor(target.width / 2), Math.floor(target.height / 2), lowBitrate, 15, 'medium')
  return { name: `screenshare-${target.height}p-${target.frameRate}fps`, videoCodec: 'vp8',
    simulcast: true, screenShareSimulcastLayers: [lowLayer],
    degradationPreference: target.frameRate === 60 ? 'maintain-framerate' : 'maintain-resolution',
    screenShareEncoding: { maxBitrate: target.bitrate, maxFramerate: target.frameRate, priority: 'medium' } }
}
