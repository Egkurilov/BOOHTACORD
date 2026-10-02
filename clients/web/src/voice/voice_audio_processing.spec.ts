import { describe, expect, it } from 'vitest'

import type { VoiceRoom } from './livekit_gateway'
import { VoiceAudioProcessing } from './voice_audio_processing'

describe('voice audio processing', () => {
  it('reports the active microphone settings separately from the selected preferences', async () => {
    const room = {
      readAudioProcessingSettings: () => ({ autoGainControl: false, echoCancellation: true, noiseSuppression: false }),
    }
    const processing = new VoiceAudioProcessing(() => ({ room: room as VoiceRoom }))

    await processing.set({ autoGainControl: true, echoCancellation: false, noiseSuppression: true })

    expect(processing.diagnostics).toEqual({
      autoGainControl: { requested: true, reported: 'DISABLED' },
      echoCancellation: { requested: false, reported: 'ENABLED' },
      noiseSuppression: { requested: true, reported: 'DISABLED' },
    })
  })
})
