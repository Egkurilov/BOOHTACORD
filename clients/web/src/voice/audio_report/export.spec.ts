import { expect, it } from 'vitest'
import { exportVoiceAudioDiagnostics, type VoiceAudioDiagnostics } from '../audio_diagnostics/model'
it('projects only anonymous fields even when extra SDK data is present', () => {
  const value = { profile: 'baseline-128-v1', capBps: 128000,
    accountId: 'private-marker', pcm: 'private-marker',
    capture: { sampleRate: 48000, channels: 1, agc: true, aec: true, ns: false,
      deviceId: 'private-marker', label: 'private-marker' },
    samples: [{ direction: 'sender', codec: 'opus', bitrateBps: 64000,
      audioLevel: 0.12345, ssrc: 'private-marker', trackId: 'private-marker', body: 'private-marker' }],
  } as unknown as VoiceAudioDiagnostics
  const text = exportVoiceAudioDiagnostics(value)
  expect(text).not.toContain('private-marker'); expect(text).not.toContain('audioLevel')
  expect(JSON.parse(text).samples[0].bitrateBps).toBe(64000)
})
it('rejects arbitrary profile/codec labels instead of exporting them', () => {
  const text = exportVoiceAudioDiagnostics({ profile: 'private-marker', capBps: 128000,
    capture: {}, samples: [{ direction: 'receiver', codec: 'private-marker' }],
  } as unknown as VoiceAudioDiagnostics)
  expect(text).not.toContain('private-marker')
})
