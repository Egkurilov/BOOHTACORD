import { describe, expect, it } from 'vitest'

import { audioProcessingStatus, describeAudioProcessing } from './audio_processing_diagnostics'

describe('audio processing diagnostics', () => {
  it('keeps browser-reported values distinct from requested constraints', () => {
    expect(describeAudioProcessing(
      { autoGainControl: true, echoCancellation: false, noiseSuppression: true },
      { autoGainControl: true, echoCancellation: false },
    )).toEqual({
      autoGainControl: { requested: true, reported: 'ENABLED' },
      echoCancellation: { requested: false, reported: 'DISABLED' },
      noiseSuppression: { requested: true, reported: 'UNAVAILABLE' },
    })
  })

  it('explains an unavailable browser report without calling it unsupported', () => {
    expect(audioProcessingStatus({ requested: true, reported: 'UNAVAILABLE' })).toBe('Запрошено: включено; браузер не сообщил состояние.')
  })
})
