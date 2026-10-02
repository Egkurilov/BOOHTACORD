import { vi } from 'vitest'
import type { ProfileTrack } from './types'

export function profileTrack() {
  let settings: MediaTrackSettings = { width: 2560, height: 1440, frameRate: 60 }
  let parameters = { encodings: [{ rid: 'h', scaleResolutionDownBy: 1 }, { rid: 'l', scaleResolutionDownBy: 2, active: false }] } as RTCRtpSendParameters
  let frames = 0
  const mediaStreamTrack = {
    readyState: 'live' as MediaStreamTrackState,
    getSettings: () => settings,
    applyConstraints: vi.fn(async (constraints: MediaTrackConstraints) => {
      const width = (constraints.width as ConstrainULongRange).max!
      const height = (constraints.height as ConstrainULongRange).max!
      const scale = Math.max(1, settings.width! / width, settings.height! / height)
      settings = { width: settings.width! / scale, height: settings.height! / scale, frameRate: (constraints.frameRate as ConstrainDoubleRange).max }
    }),
  }
  const sender = {
    getParameters: () => structuredClone(parameters),
    setParameters: vi.fn(async (value: RTCRtpSendParameters) => { parameters = structuredClone(value) }),
    getStats: vi.fn(async () => new Map([['v', { id: 'v', type: 'outbound-rtp', kind: 'video', rid: 'h', framesEncoded: ++frames, frameWidth: settings.width, frameHeight: settings.height, framesPerSecond: 60 }]]) as unknown as RTCStatsReport),
  }
  const track: ProfileTrack = { mediaStreamTrack, sender }
  return { track, sender, mediaStreamTrack, setSettings: (value: MediaTrackSettings) => { settings = value },
    setParameters: (value: RTCRtpSendParameters) => { parameters = value } }
}
