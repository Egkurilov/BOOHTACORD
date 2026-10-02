import { describe, expect, it } from 'vitest'

import { audioProcessingStatus, describeAudioProcessing } from './audio_processing_diagnostics'

describe('audio processing diagnostics', () => {
  it('keeps browser-reported values distinct from requested constraints', () => {
    expect(describeAudioProcessing(
      { autoGainControl: true, echoCancellation: false, noiseSuppressionMode: 'browser' },
      { autoGainControl: true, echoCancellation: false },
    )).toMatchObject({
      autoGainControl: { requested: true, reported: 'ENABLED' },
      echoCancellation: { requested: false, reported: 'DISABLED' },
      noiseSuppression: { requested: true, reported: 'UNAVAILABLE' },
    })
  })

  it('explains an unavailable browser report without calling it unsupported', () => {
    expect(audioProcessingStatus({ requested: true, reported: 'UNAVAILABLE' })).toBe('Запрошено: включено; браузер не сообщил состояние.')
  })
})


it('does not infer RNNoise operation from browser noiseSuppression settings', () => {
  const selected = { autoGainControl: true, echoCancellation: true, noiseSuppressionMode: 'rnnoise' as const }
  expect(describeAudioProcessing(selected, { noiseSuppression: false }).noiseSuppressionRuntime).toMatchObject({ requestedMode: 'rnnoise', effectiveMode: 'unknown', status: 'idle' })
  expect(describeAudioProcessing(selected, undefined, { requestedMode: 'rnnoise', effectiveMode: 'rnnoise', status: 'active', modelId: 'model-fixed' }).noiseSuppressionRuntime).toMatchObject({ effectiveMode: 'rnnoise', modelId: 'model-fixed' })
})
