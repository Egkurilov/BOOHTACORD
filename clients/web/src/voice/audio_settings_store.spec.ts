import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

import { useAudioSettingsStore } from './audio_settings_store'

describe('audio settings store', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('keeps selected browser processing preferences after the active session applies them', async () => {
    const store = useAudioSettingsStore()
    const processing = { autoGainControl: false, echoCancellation: false, noiseSuppressionMode: 'browser' as const }
    const apply = vi.fn().mockResolvedValue(undefined)

    await store.setProcessing(processing, apply)

    expect(apply).toHaveBeenCalledWith(processing)
    expect(store.processing).toEqual(processing)
  })

  it('ignores a stale device scan after a newer hotplug scan completes', async () => {
    const store = useAudioSettingsStore()
    let finishOld!: (value: { inputs: { id: string; label: string }[]; outputs: [] }) => void
    const old = store.load(() => new Promise(resolve => { finishOld = resolve }))
    await store.load(async () => ({ inputs: [{ id: 'new', label: 'Новый микрофон' }], outputs: [] }))
    finishOld({ inputs: [{ id: 'old', label: 'Старый микрофон' }], outputs: [] })
    await old
    expect(store.devices.inputs[0]?.id).toBe('new')
    expect(store.state).toBe('READY')
  })
})
