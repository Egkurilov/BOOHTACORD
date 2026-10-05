import { describe, expect, it } from 'vitest'

import { compareScreenReceiverStats } from './screen_receiver_diagnostics'

describe('selected screen receiver diagnostics', () => {
  it('uses receiver counter deltas and timestamps for decoded FPS and bitrate', () => {
    const before = { timestamp: 1000, framesDecoded: 20, framesDropped: 1, bytesReceived: 100_000, packetsLost: 2 }
    const after = { timestamp: 3000, framesDecoded: 140, framesDropped: 4, bytesReceived: 1_100_000, packetsLost: 3, jitter: 0.012 }

    expect(compareScreenReceiverStats(before, after)).toEqual({
      bitrateKbps: 4000, decodedFrames: 140, decodedFps: 60, droppedFrames: 3, jitterMs: 12, packetsLost: 3, packetLossPercent: null,
    })
  })

  it('does not report a rate until a valid second sample is available', () => {
    const current = { timestamp: 2000, framesDecoded: 150, framesDropped: 5, bytesReceived: 900, packetsLost: 0 }
    expect(compareScreenReceiverStats(null, current)).toEqual({
      bitrateKbps: null, decodedFrames: 150, decodedFps: null, droppedFrames: null, jitterMs: null, packetsLost: 0, packetLossPercent: null,
    })
    expect(compareScreenReceiverStats({ ...current, timestamp: 3000 }, current).decodedFps).toBeNull()
    expect(compareScreenReceiverStats({ ...current, framesDecoded: 200 }, current).decodedFps).toBeNull()
    expect(compareScreenReceiverStats({ ...current, timestamp: 1000 }, { ...current, framesDecoded: Number.NaN }).decodedFps).toBeNull()
  })
})
