import { describe, expect, it } from 'vitest'

import { normalizeScreenDiagnostics } from './screen_diagnostics'

describe('screen diagnostics', () => {
  it('prefers observed sender dimensions and reports network values without using the target profile', () => {
    expect(normalizeScreenDiagnostics({
      audioTrack: true,
      connectionQuality: 'excellent',
      readyState: 'live',
      sender: { frameHeight: 720, frameWidth: 1280, framesPerSecond: 30, packetsLost: 2, qualityLimitationReason: 'bandwidth', roundTripTime: 0.04 },
      settings: { frameRate: 60, height: 1080, width: 1920 },
    })).toEqual({
      adaptationReason: 'bandwidth',
      audioTrack: 'PRESENT',
      connectionQuality: 'EXCELLENT',
      measured: { framesPerSecond: 30, height: 720, width: 1280 },
      packetsLost: 2,
      roundTripTimeMs: 40,
      source: 'ACTIVE',
    })
  })

  it('keeps unavailable tracks and measurements unknown instead of deriving them from the target profile', () => {
    expect(normalizeScreenDiagnostics({ audioTrack: false, readyState: undefined, settings: {} })).toEqual({
      audioTrack: 'UNKNOWN', connectionQuality: 'UNKNOWN', measured: null, source: 'UNKNOWN',
    })
  })

  it('does not present the capture frame rate as measured encoded FPS without sender stats', () => {
    expect(normalizeScreenDiagnostics({
      audioTrack: false, readyState: 'live', sender: { frameHeight: 1080, frameWidth: 1920 },
      settings: { frameRate: 60, height: 1080, width: 1920 },
    }).measured).toEqual({ height: 1080, width: 1920 })
    expect(normalizeScreenDiagnostics({
      audioTrack: false, readyState: 'live', settings: { frameRate: 60, height: 1080, width: 1920 },
    }).measured).toEqual({ height: 1080, width: 1920 })
  })

  it('retains zero loss and zero RTT as measured values', () => {
    expect(normalizeScreenDiagnostics({
      audioTrack: false, readyState: 'live', sender: { packetsLost: 0, roundTripTime: 0 }, settings: {},
    })).toMatchObject({ audioTrack: 'ABSENT', packetsLost: 0, roundTripTimeMs: 0, source: 'ACTIVE' })
  })
})
