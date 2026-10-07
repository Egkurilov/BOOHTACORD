import { describe, expect, it } from 'vitest'

import { inspectLiveKitScreenDiagnostics, type LiveKitScreenVideoTrack } from './screen_livekit_diagnostics'
import { screenSenderStatsSampler } from './screen_stats_sampler'

describe('LiveKit screen sender diagnostics', () => {
  it('exposes active per-layer rates while keeping total bitrate separate', async () => {
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
          ['remote-full', { id: 'remote-full', type: 'remote-inbound-rtp', localId: 'full', packetsLost: bucket * 2, roundTripTime: 0.045 }],
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
    expect(diagnostics.bitrateBps).toBeCloseTo(diagnostics.layers![1]!.bitrateBps!, 0)
    expect(diagnostics.totalBitrateBps).toBeCloseTo(diagnostics.bitrateBps! * 2, 0)
    expect(diagnostics.layers?.[1]?.packetLossPercent).toBeCloseTo(100 / 15, 1)
    expect(diagnostics.roundTripTimeMs).toBe(45)
  })
})


it('pairs capture and encode counters to the selected progressing layer rather than frozen pixels', async () => {
  let sample = 0
  const sender = { getStats: async () => {
    sample++
    const timestamp = Date.now() - (sample === 1 ? 1000 : 0)
    return new Map([
      ['source', { id: 'source', type: 'media-source', frames: sample * 30 }],
      ['high', { id: 'high', type: 'outbound-rtp', kind: 'video', active: true, timestamp, frameWidth: 1920, frameHeight: 1080,
        framesEncoded: 100, bytesSent: sample * 1000, packetsSent: sample * 10, mediaSourceId: 'source' }],
      ['low', { id: 'low', type: 'outbound-rtp', kind: 'video', active: true, timestamp, frameWidth: 640, frameHeight: 360,
        framesEncoded: sample * 30, bytesSent: sample * 1000, packetsSent: sample * 10, mediaSourceId: 'source' }],
    ]) as unknown as RTCStatsReport
  } }
  const video: LiveKitScreenVideoTrack = { sender, getSenderStats: async () => [], getSourceTrackSettings: () => ({}), mediaStreamTrack: { readyState: 'live' } }
  await inspectLiveKitScreenDiagnostics(video, false, 'good')
  screenSenderStatsSampler.clear(sender)
  const value = await inspectLiveKitScreenDiagnostics(video, false, 'good')
  expect(value.measured).toMatchObject({ width: 640, height: 360 })
  expect(value.encodedFrames).toBe(60)
  expect(value.capturedFrames).toBe(60)
})
