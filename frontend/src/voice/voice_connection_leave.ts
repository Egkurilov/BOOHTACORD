import type { Ref } from 'vue'

import type { ActiveVoiceSession, VoiceSession } from './voice_session'
import type { VoiceConnectionState } from './connection_store'
import type { ScreenDiagnostics } from './screen_diagnostics'
import { unknownScreenDiagnostics } from './screen_diagnostics'
import type { ScreenProfile } from './livekit_gateway'
import type { ScreenShareState } from './screen_controls'

interface LeaveContext {
  session: Pick<VoiceSession, 'leave' | 'active'>
  active: Ref<ActiveVoiceSession | null>
  state: Ref<VoiceConnectionState>
  error: Ref<string | null>
  deafened: Ref<boolean>
  screenDiagnostics: Ref<ScreenDiagnostics>
  screenProfile: Ref<ScreenProfile | null>
  screenState: Ref<ScreenShareState>
  screenViewer: { stop(): void }
  volume: { stop(): void }
  refreshAudioProcessingDiagnostics(): void
}

export async function leaveVoiceConnection(context: LeaveContext): Promise<void> {
  const { session, active, state, error, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics } = context
  if (!active.value || state.value === 'LEAVING') return
  state.value = 'LEAVING'
  error.value = null
  try {
    screenViewer.stop()
    volume.stop()
    await session.leave()
    active.value = null
    refreshAudioProcessingDiagnostics()
    deafened.value = false
    screenDiagnostics.value = unknownScreenDiagnostics()
    screenProfile.value = null
    screenState.value = 'IDLE'
    state.value = 'IDLE'
  } catch (cause) {
    if (!session.active) {
      active.value = null
      refreshAudioProcessingDiagnostics()
      deafened.value = false
      screenState.value = 'IDLE'
      state.value = 'IDLE'
      return
    }
    state.value = 'ERROR'
    error.value = cause instanceof Error ? cause.message : 'Не удалось завершить голосовое подключение.'
  }
}
