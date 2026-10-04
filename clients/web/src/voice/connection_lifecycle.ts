import type { Ref } from 'vue'
import type { VoiceDisconnectState } from './disconnect_notice/state'

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
  terminal?: VoiceDisconnectState,
): void {
  session.setConnectionObserver({
    admitted: (leaseID, channelID) => terminal?.bind(leaseID, channelID),
    reconnecting: () => {
      if (active.value && state.value !== 'LEAVING' && !terminal?.notice.value) {
        state.value = 'RECONNECTING'
        error.value = null
      }
    },
    reconnected: () => {
      if (active.value && !terminal?.notice.value) state.value = active.value.microphone === 'PUBLISHED' ? 'CONNECTED' : 'LISTENER'
    },
    disconnected: () => {
      if (active.value) terminal?.bind(active.value.leaseId, active.value.channelId)
      terminal?.transport()
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
      state.value = terminal?.notice.value?.source === 'local' ? 'IDLE' : 'ERROR'
      error.value = terminal?.notice.value?.source === 'local' ? null : terminal?.notice.value?.message ?? 'Голосовое соединение не восстановлено. Подключитесь снова вручную.'
    },
  })
}
