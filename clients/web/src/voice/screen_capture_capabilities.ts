import { screenCaptureSupported } from './screen_capture_support'

export type CaptureCapability = 'available' | 'unavailable' | 'unknown'
export type ReceivedTrackState = 'present' | 'absent' | 'unknown'

export interface BrowserScreenCaptureCapabilities {
  viewer: 'available'
  video: Exclude<CaptureCapability, 'unknown'>
  audio: 'unknown'
  sourceSelected: false
}

export interface ObservedScreenCaptureTracks {
  video: ReceivedTrackState
  audio: ReceivedTrackState
  sourceSelected: true
}

export function browserScreenCaptureCapabilities(
  userAgent?: string,
  mediaDevices?: { getDisplayMedia?: unknown },
): BrowserScreenCaptureCapabilities {
  const video = screenCaptureSupported(userAgent, mediaDevices) ? 'available' : 'unavailable'
  return { viewer: 'available', video, audio: 'unknown', sourceSelected: false }
}

export function observedScreenCaptureTracks(tracks: { videoTrack: boolean | null; audioTrack: boolean | null }): ObservedScreenCaptureTracks {
  return {
    video: receivedTrackState(tracks.videoTrack),
    audio: receivedTrackState(tracks.audioTrack),
    sourceSelected: true,
  }
}

function receivedTrackState(present: boolean | null): ReceivedTrackState {
  return present === null ? 'unknown' : present ? 'present' : 'absent'
}
