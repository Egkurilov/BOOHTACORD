import { ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { createDeafenControls } from './deafen_controls'

describe('deafen controls', () => {
  it('updates deafen and microphone UI state from the session result', async () => {
    const session = { setDeafened: vi.fn().mockResolvedValueOnce('MUTED').mockResolvedValueOnce('PUBLISHED') }
    const deafened = ref(false)
    const microphoneMuted = ref(false)
    const microphonePermissionDenied = ref(false)
    const error = ref<string | null>(null)
    const controls = createDeafenControls(session, deafened, microphoneMuted, microphonePermissionDenied, error)

    await controls.toggleDeafen()
    await controls.toggleDeafen()

    expect(session.setDeafened).toHaveBeenNthCalledWith(1, true)
    expect(session.setDeafened).toHaveBeenNthCalledWith(2, false)
    expect(deafened.value).toBe(false)
    expect(microphoneMuted.value).toBe(false)
    expect(microphonePermissionDenied.value).toBe(false)
    expect(error.value).toBeNull()
  })

  it('keeps deafen state unchanged and reports a failed transition', async () => {
    const session = { setDeafened: vi.fn().mockRejectedValue(new Error('media failed')) }
    const deafened = ref(false)
    const error = ref<string | null>(null)
    const controls = createDeafenControls(session, deafened, ref(false), ref(false), error)

    await controls.toggleDeafen()

    expect(deafened.value).toBe(false)
    expect(error.value).toBe('media failed')
  })
})
