import { describe, expect, it } from 'vitest'

import { readVoiceConnectionStats, voiceConnectionQuality } from './voice_connection_quality'

describe('voice connection quality', () => {
  it('normalizes LiveKit quality values for the shared dock', () => {
    expect(voiceConnectionQuality('excellent')).toBe('EXCELLENT')
    expect(voiceConnectionQuality('GOOD')).toBe('GOOD')
    expect(voiceConnectionQuality('poor')).toBe('POOR')
    expect(voiceConnectionQuality('lost')).toBe('LOST')
    expect(voiceConnectionQuality(undefined)).toBe('UNKNOWN')
    expect(voiceConnectionQuality('unexpected')).toBe('UNKNOWN')
  })

  it('reads only a bounded RTT from the remote inbound audio report', () => {
    expect(readVoiceConnectionStats('good', [
      { type: 'outbound-rtp', roundTripTime: 0.01 },
      { type: 'remote-inbound-rtp', roundTripTime: 0.0424 },
    ])).toEqual({ quality: 'GOOD', pingMs: 42 })
    expect(readVoiceConnectionStats('good', [
      { type: 'remote-inbound-rtp', roundTripTime: 61 },
    ])).toEqual({ quality: 'GOOD', pingMs: null })
    expect(readVoiceConnectionStats('good', undefined)).toEqual({
      quality: 'GOOD',
      pingMs: null,
    })
  })
})
