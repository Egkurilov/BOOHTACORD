import type { Ref } from 'vue'

import type { VoiceConnectionState } from './connection_store'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenShareState } from './screen_controls'
import type { ScreenProfile } from './livekit_gateway'
import type { ActiveVoiceSession, VoiceSession } from './voice_session'

interface Stoppable { stop(): void }

export function installVoiceConnectionLifecycle(
  session: Pick<VoiceSession, 'setConnectionObserver'>,
  active: Ref<ActiveVoiceSession | null>,
  state: Ref<VoiceConnectionState>,
  error: Ref<string | null>,
  microphoneMuted: Ref<boolean>,
  microphonePermissionDenied: Ref<boolean>,
  deafened: Ref<boolean>,
  screenDiagnostics: Ref<ScreenDiagnostics>,
  screenProfile: Ref<ScreenProfile | null>,
  screenState: Ref<ScreenShareState>,
  screenViewer: Stoppable,
  volume: Stoppable,
  refreshAudioProcessingDiagnostics: () => void,
): void {
  session.setConnectionObserver({
    reconnecting: () => {
      if (active.value && state.value !== 'LEAVING') {
        state.value = 'RECONNECTING'
        error.value = null
      }
    },
    reconnected: () => {
      if (active.value) state.value = active.value.microphone === 'PUBLISHED' ? 'CONNECTED' : 'LISTENER'
    },
    disconnected: () => {
      screenViewer.stop()
      volume.stop()
      active.value = null
      refreshAudioProcessingDiagnostics()
      deafened.value = false
      microphoneMuted.value = false
      microphonePermissionDenied.value = false
      screenDiagnostics.value = unknownScreenDiagnostics()
      screenProfile.value = null
      screenState.value = 'IDLE'
      state.value = 'ERROR'
      error.value = 'Голосовое соединение не восстановлено. Подключитесь снова вручную.'
    },
  })
}
