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
  it('manual capture promotes listener state after the existing session publishes', async () => {
    const state=ref('LISTENER'),session={setMicrophoneMuted:vi.fn(async () => 'PUBLISHED' as const)}
    const controls=createMicrophoneControls(session,ref({}),state,ref(false),ref(true),ref(false),ref(null))
    await controls.setMicrophoneMuted(false); expect(state.value).toBe('CONNECTED')
  })

  it('retries microphone permission with one click from the listener state', async () => {
    const state = ref('LISTENER')
    const microphoneMuted = ref(false)
    const microphonePermissionDenied = ref(true)
    const session = {
      setMicrophoneMuted: vi.fn(async (muted: boolean) => muted ? 'MUTED' as const : 'PUBLISHED' as const),
    }
    const controls = createMicrophoneControls(
      session, ref({}), state, ref(false), microphoneMuted, microphonePermissionDenied, ref(null),
    )

    await controls.toggleMicrophone()

    expect(session.setMicrophoneMuted).toHaveBeenCalledExactlyOnceWith(false)
    expect(state.value).toBe('CONNECTED')
    expect(microphoneMuted.value).toBe(false)
    expect(microphonePermissionDenied.value).toBe(false)
  })

})
