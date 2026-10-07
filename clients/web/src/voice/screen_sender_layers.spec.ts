import { describe, expect, it } from 'vitest'

import { ScreenSenderLayerSampler, type RawScreenLayerStats } from './screen_sender_layers'

const layer = (overrides: Partial<RawScreenLayerStats> = {}): RawScreenLayerStats => ({
  id: 'outbound-1', timestamp: 1000, ssrc: 10, rid: 'f', active: true,
  frameWidth: 1920, frameHeight: 1080, framesEncoded: 0, bytesSent: 0,
  retransmittedBytesSent: 0, packetsSent: 0, packetsLost: 0, ...overrides,
})

describe('screen sender layer sampling', () => {
  it('selects the highest active layer and keeps its FPS separate from other layer FPS', () => {
    const sampler = new ScreenSenderLayerSampler()
    sampler.sample([layer(), layer({ id: 'low', rid: 'q', frameWidth: 640, frameHeight: 360 })], 1000)
    const result = sampler.sample([
      layer({ timestamp: 2000, framesEncoded: 30, bytesSent: 100000, packetsSent: 100, packetsLost: 2 }),
      layer({ id: 'low', rid: 'q', frameWidth: 640, frameHeight: 360, timestamp: 2000, framesEncoded: 30, bytesSent: 50000, packetsSent: 50, packetsLost: 1 }),
    ], 2000)
    expect(result.selected).toMatchObject({ rid: 'f', framesPerSecond: 30, bitrateBps: 800000 })
    expect(result.layers.map(value => value.framesPerSecond)).toEqual([30, 30])
    sampler.clear()
    expect(sampler.sample([layer({ timestamp: 2000, framesEncoded: 30 })], 2000).selected?.framesPerSecond).toBeNull()
  })

  it('excludes inactive layers and reports a counter reset as unavailable for that interval', () => {
    const sampler = new ScreenSenderLayerSampler()
    sampler.sample([layer()], 1000)
    const result = sampler.sample([
      layer({ timestamp: 2000, framesEncoded: 30, bytesSent: 1000 }),
      layer({ id: 'inactive', rid: 'h', active: false, timestamp: 2000, frameWidth: 3840, frameHeight: 2160, framesEncoded: 40, bytesSent: 5000 }),
    ], 2000)
    expect(result.selected?.id).toBe('outbound-1')
    const reset = sampler.sample([layer({ timestamp: 3000, framesEncoded: 2, bytesSent: 2 })], 3000)
    expect(reset.selected).toMatchObject({ framesPerSecond: null, bitrateBps: null })
  })

  it('marks stale samples unavailable and rejects negative loss counters', () => {
    const sampler = new ScreenSenderLayerSampler()
    sampler.sample([layer({ packetsLost: -1 })], 1000)
    const result = sampler.sample([layer({ timestamp: 2000, framesEncoded: 30, bytesSent: 1000, packetsSent: 10, packetsLost: -1 })], 20000)
    expect(result.layers[0]).toMatchObject({ state: 'STALE', framesPerSecond: null, packetLossPercent: null })
  })
})
