import { describe, expect, it } from 'vitest'

import { inspectLiveKitScreenDiagnostics, type LiveKitScreenVideoTrack } from './screen_livekit_diagnostics'
import { screenSenderStatsSampler } from './screen_stats_sampler'

describe('LiveKit screen sender diagnostics', () => {
  it('exposes active per-layer rates while keeping SDK total bitrate separate', async () => {
    let sample = 0
    const sender = {
      getStats: async () => {
        sample += 1
        const bucket = sample
        const timestamp = Date.now() - (bucket === 1 ? 1000 : 0)
        const frame = (id: string, rid: string, width: number, count: number) => ({
          id, type: 'outbound-rtp', kind: 'video', codecId: 'vp8', timestamp, rid, active: true,
          ssrc: id === 'full' ? 2 : 1, frameWidth: width, frameHeight: width * 9 / 16,
          framesEncoded: count, bytesSent: count * 1000, retransmittedBytesSent: 0,
          packetsSent: count, packetsLost: 0,
        })
        return new Map<string, Record<string, unknown>>([
          ['codec', { id: 'vp8', type: 'codec', mimeType: 'video/VP8' }],
          ['low', frame('low', 'q', 640, bucket * 30)], ['full', frame('full', 'f', 1920, bucket * 30)],
        ]) as unknown as RTCStatsReport
      },
    }
    const video: LiveKitScreenVideoTrack = {
      sender, currentBitrate: 2_500_000, getSenderStats: async () => [],
      getSourceTrackSettings: () => ({ width: 1920, height: 1080 }), mediaStreamTrack: { readyState: 'live' },
    }
    await inspectLiveKitScreenDiagnostics(video, false, 'good')
    screenSenderStatsSampler.clear(sender)
    const diagnostics = await inspectLiveKitScreenDiagnostics(video, false, 'good')
    expect(diagnostics.layers).toHaveLength(2)
    expect(diagnostics.layers?.[0]?.framesPerSecond).toBeCloseTo(30, 0)
    expect(diagnostics.layers?.[1]?.framesPerSecond).toBeCloseTo(30, 0)
    expect(diagnostics.measured).toMatchObject({ width: 1920, height: 1080 })
    expect(diagnostics.measured?.framesPerSecond).toBeCloseTo(30, 0)
    expect(diagnostics.bitrateBps).toBe(2_500_000)
  })
})
