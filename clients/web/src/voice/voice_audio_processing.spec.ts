import { describe, expect, it, vi } from 'vitest'

import type { VoiceRoom } from './livekit_gateway'
import { VoiceAudioProcessing } from './voice_audio_processing'

describe('voice audio processing', () => {
  it('reports the active microphone settings separately from the selected preferences', async () => {
    const room = {
      readAudioProcessingSettings: () => ({ autoGainControl: false, echoCancellation: true, noiseSuppression: false }),
    }
    const processing = new VoiceAudioProcessing(() => ({ room: room as VoiceRoom }))

    await processing.set({ autoGainControl: true, echoCancellation: false, noiseSuppressionMode: 'browser' })

    expect(processing.diagnostics).toMatchObject({
      autoGainControl: { requested: true, reported: 'DISABLED' },
      echoCancellation: { requested: false, reported: 'ENABLED' },
      noiseSuppression: { requested: true, reported: 'DISABLED' },
    })
  })
})


it('retains preferences after failed active-track mutation', async () => {
  const apply = vi.fn().mockRejectedValue(new Error('constraints'))
  const processing = new VoiceAudioProcessing(() => ({ room: { applyMicrophoneProcessing: apply } as unknown as VoiceRoom }))
  await expect(processing.set({ autoGainControl: false, echoCancellation: false, noiseSuppressionMode: 'rnnoise' })).rejects.toThrow('constraints')
  expect(processing.value).toEqual({ autoGainControl: true, echoCancellation: true, noiseSuppressionMode: 'browser' })
})
