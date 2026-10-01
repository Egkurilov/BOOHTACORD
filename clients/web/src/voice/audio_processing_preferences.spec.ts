import { describe, expect, it } from 'vitest'

import { defaultAudioProcessing } from './livekit_gateway'
import { AudioProcessingPreferences } from './audio_processing_preferences'

function storage() {
  const values = new Map<string, string>()
  return { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => values.set(key, value) }
}

describe('audio processing preferences', () => {
  it('persists browser processing settings for the current account only', () => {
    const local = storage()
    const owner = new AudioProcessingPreferences(local)
    const other = new AudioProcessingPreferences(local)
    const selected = { autoGainControl: false, echoCancellation: false, noiseSuppression: true }
    owner.bind('owner-a')
    other.bind('owner-b')

    owner.set(selected)

    expect(owner.get()).toEqual(selected)
    expect(other.get()).toEqual(defaultAudioProcessing)
  })

  it('falls back to safe defaults when stored data is malformed or incomplete', () => {
    const local = storage()
    const preferences = new AudioProcessingPreferences(local)
    preferences.bind('owner-a')
    local.setItem('audio-processing:v1:owner-a', '{"autoGainControl":false}')

    expect(preferences.get()).toEqual(defaultAudioProcessing)
  })
})
