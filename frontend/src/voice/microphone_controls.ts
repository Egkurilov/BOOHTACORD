import type { Ref } from 'vue'

import type { MicrophoneState } from './livekit_gateway'

export interface MicrophoneSession {
  setMicrophoneMuted(muted: boolean): Promise<MicrophoneState>
}

export function createMicrophoneControls(
  session: MicrophoneSession,
  active: Ref<unknown | null>,
  state: Ref<string>,
  deafened: Ref<boolean>,
  microphoneMuted: Ref<boolean>,
  microphonePermissionDenied: Ref<boolean>,
  error: Ref<string | null>,
) {
  async function setMicrophoneMuted(muted: boolean): Promise<void> {
    if (!active.value || deafened.value) return
    error.value = null
    try {
      const microphone = await session.setMicrophoneMuted(muted)
      microphoneMuted.value = microphone === 'MUTED'
      microphonePermissionDenied.value = microphone === 'LISTENER_PERMISSION_DENIED'
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось изменить состояние микрофона.'
    }
  }

  async function toggleMicrophone(): Promise<void> {
    if (['JOINING', 'RECONNECTING', 'LEAVING'].includes(state.value)) return
    await setMicrophoneMuted(!microphoneMuted.value)
  }

  return { setMicrophoneMuted, toggleMicrophone }
}
