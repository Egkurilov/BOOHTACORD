import { describe, expect, it } from 'vitest'

import { ScreenPacketLossWindow } from './screen_packet_loss'

describe('screen receiver packet loss', () => {
  it('reports the loss percentage over a ten-second window rather than lifetime loss', () => {
    const window = new ScreenPacketLossWindow()
    expect(window.add({ timestamp: 0, packetsReceived: 1000, packetsLost: 2476 })).toBeNull()
    expect(window.add({ timestamp: 2000, packetsReceived: 1195, packetsLost: 2481 })).toBeNull()
    expect(window.add({ timestamp: 8000, packetsReceived: 1795, packetsLost: 2481 })).toBeNull()
    expect(window.add({ timestamp: 10000, packetsReceived: 1995, packetsLost: 2481 })).toBe(0.5)
    expect(window.add({ timestamp: 12000, packetsReceived: 2195, packetsLost: 2481 })).toBe(0)
  })

  it('resets on counter rollover, missing stats, or a gap in sampling', () => {
    const window = new ScreenPacketLossWindow()
    expect(window.add({ timestamp: 0, packetsReceived: 100, packetsLost: 1 })).toBeNull()
    expect(window.add({ timestamp: 10000, packetsReceived: 100, packetsLost: 1 })).toBeNull()
    expect(window.add({ timestamp: 12000, packetsReceived: 1, packetsLost: 0 })).toBeNull()
    expect(window.add({ timestamp: 22000, packetsReceived: 91, packetsLost: 10 })).toBe(10)
    expect(window.add({ timestamp: 40000, packetsReceived: 100, packetsLost: 11 })).toBeNull()
    expect(window.add({ timestamp: 50000, packetsReceived: 200, packetsLost: 20 })).toBe(8.26)
    expect(window.add({ timestamp: 52000, packetsReceived: undefined, packetsLost: 21 })).toBeNull()
  })
})
