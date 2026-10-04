import type { Ref } from 'vue'
import type { VoiceDisconnectState } from './disconnect_notice/state'

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
  terminal?: VoiceDisconnectState
  refreshAudioProcessingDiagnostics(): void
}

export async function leaveVoiceConnection(context: LeaveContext): Promise<void> {
  const { session, active, state, error, deafened, screenDiagnostics, screenProfile, screenState, screenViewer, volume, refreshAudioProcessingDiagnostics } = context
  if (!active.value || state.value === 'LEAVING') return
  context.terminal?.bind(active.value.leaseId, active.value.channelId)
  context.terminal?.local()
  const leaving = active.value
  state.value = 'LEAVING'
  error.value = null
  try {
    screenViewer.stop()
    volume.stop()
    await session.leave()
    if (active.value && active.value !== leaving) return
    active.value = null
    refreshAudioProcessingDiagnostics()
    deafened.value = false
    screenDiagnostics.value = unknownScreenDiagnostics()
    screenProfile.value = null
    screenState.value = 'IDLE'
    state.value = context.terminal?.notice.value?.source === 'server' ? 'ERROR' : 'IDLE'
    error.value = context.terminal?.notice.value?.source === 'server' ? context.terminal.notice.value.message : null
  } catch (cause) {
    if (active.value && active.value !== leaving) return
    if (!session.active) {
      active.value = null
      refreshAudioProcessingDiagnostics()
      deafened.value = false
      screenState.value = 'IDLE'
      state.value = context.terminal?.notice.value?.source === 'server' ? 'ERROR' : 'IDLE'
      error.value = context.terminal?.notice.value?.source === 'server' ? context.terminal.notice.value.message : null
      return
    }
    state.value = 'ERROR'
    error.value = context.terminal?.notice.value?.source === 'server' ? context.terminal.notice.value.message : cause instanceof Error ? cause.message : 'Не удалось завершить голосовое подключение.'
  }
}
