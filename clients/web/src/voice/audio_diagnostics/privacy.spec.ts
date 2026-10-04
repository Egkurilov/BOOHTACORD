import { expect, it } from 'vitest'
import { exportVoiceAudioDiagnostics, type AudioSample } from './model'
import { audioTelemetryAttributes } from './telemetry'
it('exports no audio level and quantizes telemetry without identifiers', () => {
  const sample = { direction: 'sender', codec: 'opus', codecChannels: 2, clockRate: 48000,
    bitrateBps: 65123, jitterMs: 12.34, lossPercent: 1.2, packets: 123,
    concealedSamples: 501, concealmentEvents: 2, audioLevel: 0.123456,
  } as AudioSample
  const snapshot = { profile: 'baseline-128-v1', capBps: 128000,
    capture: { sampleRate: 48000, channels: 1, agc: true, aec: true, ns: true }, samples: [sample] }
  expect(exportVoiceAudioDiagnostics(snapshot)).not.toContain('audioLevel')
  const attrs = audioTelemetryAttributes(snapshot.profile, sample)
  expect(attrs.bitrate_kbps).toBe('64'); expect(attrs.jitter_ms).toBe('10')
  expect(attrs.loss_percent).toBe('1'); expect(attrs.concealed_samples).toBe('480')
  expect(JSON.stringify(attrs)).not.toContain('0.123456')
  expect(Object.keys(attrs)).not.toContain('device.label')
})
