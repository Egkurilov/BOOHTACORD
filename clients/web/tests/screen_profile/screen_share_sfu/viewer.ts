import { RoomEvent, Track, type RemoteTrack, type RemoteTrackPublication, type Room } from 'livekit-client'
import { sanitizeTrackStats } from '../baseline/stats'

export class ScreenShareViewer {
  private publication: RemoteTrackPublication | null = null
  private track: RemoteTrack | null = null
  private readonly video = document.querySelector<HTMLVideoElement>('#remote-screen')!
  private frameCallbacks = 0
  private callbackId: number | null = null
  private captureStartedAt = 0
  private firstFrameLatencyMs: number | null = null
  private publisherRemoved = false

  bind(room: Room) {
    room.on(RoomEvent.TrackPublished, publication => {
      if (publication.kind === Track.Kind.Video) this.publication = publication
    })
    room.on(RoomEvent.TrackUnpublished, publication => {
      if (this.publication === publication) {
        this.publication = null
        this.publisherRemoved = true
      }
    })
    room.on(RoomEvent.TrackSubscribed, track => this.attach(track))
    room.on(RoomEvent.TrackUnsubscribed, track => this.detach(track))
  }

  select() { this.requirePublication().setSubscribed(true) }
  unselect() { this.requirePublication().setSubscribed(false) }

  async snapshot() {
    const stats = sanitizeTrackStats(await this.track?.getRTCStatsReport(), 'inbound')
    const activeVideoTracks = this.video.srcObject instanceof MediaStream
      ? this.video.srcObject.getVideoTracks().filter(track => track.readyState === 'live').length : 0
    return {
      publicationDiscovered: this.publication !== null,
      subscriptionActive: this.publication?.isSubscribed ?? false,
      activeVideoTracks,
      presentedFrameCallbacks: this.frameCallbacks,
      firstFrameLatencyMs: this.firstFrameLatencyMs,
      inboundFramesDecoded: stats.layers.reduce((sum, layer) => sum + (layer.framesDecoded ?? 0), 0),
      videoWidth: this.video.videoWidth,
      videoHeight: this.video.videoHeight,
      publisherRemoved: this.publisherRemoved,
    }
  }

  stop() {
    this.stopFrameSampling()
    this.track?.detach(this.video)
    this.video.pause()
    this.video.srcObject = null
    this.track = null
    this.publication = null
  }

  private attach(track: RemoteTrack) {
    if (track.kind !== Track.Kind.Video || this.track) return
    this.track = track
    this.captureStartedAt = performance.now()
    track.attach(this.video)
    void this.video.play().catch(() => undefined)
    this.sampleFrames()
  }

  private detach(track: RemoteTrack) {
    if (this.track !== track) return
    this.stopFrameSampling()
    track.detach(this.video)
    this.video.pause()
    this.video.srcObject = null
    this.track = null
  }

  private requirePublication() {
    if (!this.publication) throw new Error('discovered viewer publication required')
    return this.publication
  }

  private sampleFrames() {
    if (!this.video.requestVideoFrameCallback || this.callbackId !== null) return
    this.callbackId = this.video.requestVideoFrameCallback(() => {
      this.frameCallbacks++
      if (this.firstFrameLatencyMs === null) this.firstFrameLatencyMs = performance.now() - this.captureStartedAt
      this.callbackId = null
      this.sampleFrames()
    })
  }

  private stopFrameSampling() {
    if (this.callbackId !== null) this.video.cancelVideoFrameCallback(this.callbackId)
    this.callbackId = null
  }
}
