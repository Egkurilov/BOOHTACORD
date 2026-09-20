import { ref, type Ref } from 'vue'

import type { MicrophoneState } from './livekit_gateway'

export interface DeafenSession {
  setDeafened(deafened: boolean): Promise<MicrophoneState>
}

export function createDeafenControls(
  session: DeafenSession,
  deafened: Ref<boolean>,
  microphoneMuted: Ref<boolean>,
  microphonePermissionDenied: Ref<boolean>,
  error: Ref<string | null>,
) {
  const deafenChanging = ref(false)

  async function toggleDeafen(): Promise<void> {
    if (deafenChanging.value) return
    const next = !deafened.value
    deafenChanging.value = true
    error.value = null
    try {
      const microphone = await session.setDeafened(next)
      deafened.value = next
      microphoneMuted.value = microphone === 'MUTED'
      microphonePermissionDenied.value = microphone === 'LISTENER_PERMISSION_DENIED'
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось изменить deafen.'
    } finally {
      deafenChanging.value = false
    }
  }

  return { deafenChanging, toggleDeafen }
}
