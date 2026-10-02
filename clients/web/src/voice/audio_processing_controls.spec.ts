import { describe, expect, it, vi } from 'vitest'

import { AudioProcessingPreferences } from './audio_processing_preferences'
import { createAudioProcessingControls } from './audio_processing_controls'

function storage() {
  const values = new Map<string, string>()
  return { getItem: (key: string) => values.get(key) ?? null, setItem: (key: string, value: string) => values.set(key, value) }
}

describe('audio processing controls', () => {
  it('loads account-scoped settings before passing constraints to the voice session', async () => {
    const preferences = new AudioProcessingPreferences(storage())
    const selected = { autoGainControl: false, echoCancellation: true, noiseSuppressionMode: 'off' as const }
    preferences.bind('owner-a')
    preferences.set(selected)
    const apply = vi.fn().mockResolvedValue(undefined)
    const controls = createAudioProcessingControls(async () => ({ accountId: 'owner-a' }), preferences)

    await controls.start(apply)

    expect(apply).toHaveBeenCalledWith(selected)
    expect(controls.processing.value).toEqual(selected)
  })

  it('writes settings only after the voice session accepts the change', async () => {
    const preferences = new AudioProcessingPreferences(storage())
    const controls = createAudioProcessingControls(async () => ({ accountId: 'owner-a' }), preferences)
    const rejected = vi.fn().mockRejectedValue(new Error('unsupported'))
    const selected = { autoGainControl: false, echoCancellation: false, noiseSuppressionMode: 'off' as const }

    await controls.start(vi.fn().mockResolvedValue(undefined))
    await controls.set(selected, rejected)

    expect(preferences.get()).toEqual({ autoGainControl: true, echoCancellation: true, noiseSuppressionMode: 'browser' as const })
    expect(controls.processing.value).toEqual({ autoGainControl: true, echoCancellation: true, noiseSuppressionMode: 'browser' as const })
  })
})
