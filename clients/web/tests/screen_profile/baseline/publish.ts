import { LocalVideoTrack, Track, type Room } from 'livekit-client'
import { baselinePlan } from './settings'

export async function publishBaselineCapture(
  room: Room,
  stream: MediaStream,
  onEnded: () => void,
): Promise<LocalVideoTrack> {
  const mediaTrack = stream.getVideoTracks()[0]
  if (!mediaTrack) throw new Error('video track unavailable')
  mediaTrack.contentHint = 'motion'
  const track = new LocalVideoTrack(mediaTrack)
  mediaTrack.onended = onEnded
  await room.localParticipant.publishTrack(track, {
    name: 'baseline-screen', source: Track.Source.ScreenShare, videoCodec: baselinePlan.codec,
    screenShareEncoding: { maxFramerate: baselinePlan.frameRate, maxBitrate: baselinePlan.bitrateBps },
    degradationPreference: 'maintain-framerate', simulcast: false,
    videoSimulcastLayers: [], screenShareSimulcastLayers: [],
  })
  return track
}
