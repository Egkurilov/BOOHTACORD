import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useAudioSettingsStore } from './audio_settings_store'

describe('audio settings store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('keeps selected browser processing preferences after the active session applies them', async () => {
    const store = useAudioSettingsStore()
    const processing = { autoGainControl: false, echoCancellation: false, noiseSuppression: true }
    const apply = vi.fn().mockResolvedValue(undefined)

    await store.setProcessing(processing, apply)

    expect(apply).toHaveBeenCalledWith(processing)
    expect(store.processing).toEqual(processing)
  })
})
