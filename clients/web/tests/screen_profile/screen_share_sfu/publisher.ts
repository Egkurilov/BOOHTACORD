import { LocalVideoTrack, Track, type Room } from 'livekit-client'
import { sanitizeTrackStats } from '../baseline/stats'
import { createSyntheticScreen } from './capture'

export class SyntheticScreenPublisher {
  private track: LocalVideoTrack | null = null
  private capture: ReturnType<typeof createSyntheticScreen> | null = null

  async publish(room: Room) {
    this.capture = createSyntheticScreen()
    this.track = new LocalVideoTrack(this.capture.stream.getVideoTracks()[0]!)
    await room.localParticipant.publishTrack(this.track, {
      name: 'synthetic-screen', source: Track.Source.ScreenShare, simulcast: false,
      screenShareEncoding: { maxFramerate: 15, maxBitrate: 1_000_000 },
      degradationPreference: 'maintain-framerate',
    })
  }

  async snapshot() {
    const stats = sanitizeTrackStats(await this.track?.getRTCStatsReport(), 'outbound')
    return {
      sourceCapture: this.capture?.stream.getVideoTracks()[0]?.getSettings() ?? null,
      syntheticFramesProduced: this.capture?.generatedFrames ?? 0,
      outboundFramesEncoded: stats.layers.reduce((sum, layer) => sum + (layer.framesEncoded ?? 0), 0),
    }
  }

  async stop(room: Room | null) {
    if (this.track && room) await room.localParticipant.unpublishTrack(this.track, true).catch(() => undefined)
    this.track?.stop()
    this.track = null
    this.capture?.stop()
    this.capture = null
  }
}
