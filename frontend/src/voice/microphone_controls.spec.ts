import { ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { createMicrophoneControls } from './microphone_controls'

describe('microphone controls', () => {
  it('does not unmute through a microphone or PTT callback while deafened', async () => {
    const session = { setMicrophoneMuted: vi.fn() }
    const controls = createMicrophoneControls(session, ref({}), ref('CONNECTED'), ref(true), ref(true), ref(false), ref(null))

    await controls.setMicrophoneMuted(false)
    await controls.toggleMicrophone()

    expect(session.setMicrophoneMuted).not.toHaveBeenCalled()
  })
})
