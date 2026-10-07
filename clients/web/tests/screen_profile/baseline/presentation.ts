import { Track, type RemoteTrack } from 'livekit-client'

export class BaselinePresentation {
  private connectedAt = 0
  private firstFrameLatencyMs: number | null = null
  private firstFrameResolver: ((value: number) => void) | null = null
  private presentedFrameCallbacks = 0
  private presentationTimestamps: number[] = []
  private callbackId: number | null = null
  private remoteTrack: RemoteTrack | null = null
  private video: HTMLVideoElement | null = null

  start(monotonicMs: number) {
    this.connectedAt = monotonicMs
  }

  attach(track: RemoteTrack, video: HTMLVideoElement) {
    if (track.kind !== Track.Kind.Video || this.remoteTrack) return
    this.remoteTrack = track
    this.video = video
    track.attach(video)
    void video.play().catch(() => undefined)
    this.observe(video)
  }

  private observe(video: HTMLVideoElement) {
    const next = () => {
      if (typeof video.requestVideoFrameCallback !== 'function') return
      this.callbackId = video.requestVideoFrameCallback(() => {
        const now = performance.now()
        this.presentedFrameCallbacks++
        this.presentationTimestamps.push(now)
        if (this.presentationTimestamps.length > 1200) this.presentationTimestamps.shift()
        if (this.firstFrameLatencyMs === null) {
          this.firstFrameLatencyMs = now - this.connectedAt
          this.firstFrameResolver?.(this.firstFrameLatencyMs)
          this.firstFrameResolver = null
        }
        next()
      })
    }
    next()
  }

  waitForFirstFrame(timeoutMs: number) {
    if (this.firstFrameLatencyMs !== null) return Promise.resolve(this.firstFrameLatencyMs)
    return new Promise<number>((resolve, reject) => {
      const timeout = window.setTimeout(() => reject(new Error('viewer did not present a frame')), timeoutMs)
      this.firstFrameResolver = value => { window.clearTimeout(timeout); resolve(value) }
    })
  }

  snapshot() {
    const quality = this.video?.getVideoPlaybackQuality()
    return {
      firstFrameLatencyMs: this.firstFrameLatencyMs,
      presentedFrameCallbacks: this.presentedFrameCallbacks,
      presentationTimestamps: [...this.presentationTimestamps],
      playbackQuality: quality ? { totalVideoFrames: quality.totalVideoFrames, droppedVideoFrames: quality.droppedVideoFrames } : null,
    }
  }

  stop() {
    if (this.callbackId !== null) this.video?.cancelVideoFrameCallback(this.callbackId)
    this.remoteTrack?.detach()
    this.video?.pause()
    if (this.video) this.video.srcObject = null
    this.remoteTrack = null
    this.video = null
  }
}
