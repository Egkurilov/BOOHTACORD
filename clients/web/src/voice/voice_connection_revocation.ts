import type { Ref } from 'vue'

import type { ActiveVoiceSession, VoiceSession } from './voice_session'
import type { VoiceConnectionState } from './connection_store'
import { unknownScreenDiagnostics, type ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenProfile } from './livekit_gateway'
import type { ScreenShareState } from './screen_controls'
import { voiceLeaseRevocationMessage, type VoiceLeaseRevocationReason } from './voice_lease_revocation_reason'

interface RevocationContext {
  session: Pick<VoiceSession, 'revoke'>
  active: Ref<ActiveVoiceSession | null>
  state: Ref<VoiceConnectionState>
  error: Ref<string | null>
  deafened: Ref<boolean>
  microphoneMuted: Ref<boolean>
  microphonePermissionDenied: Ref<boolean>
  screenDiagnostics: Ref<ScreenDiagnostics>
  screenProfile: Ref<ScreenProfile | null>
  screenState: Ref<ScreenShareState>
  screenViewer: { stop(): void }
  volume: { stop(): void }
  refreshAudioProcessingDiagnostics(): void
}

export function createVoiceConnectionRevocation(context: RevocationContext) {
  const { session, active, state, error, screenViewer, volume } = context
  let pendingLocalReason: VoiceLeaseRevocationReason | null = null
  const pendingLeaseReasons = new Map<string, VoiceLeaseRevocationReason>()

  function takeJoinRevocation(leaseID: string): VoiceLeaseRevocationReason | null {
    const reason = pendingLocalReason ?? pendingLeaseReasons.get(leaseID) ?? null
    pendingLocalReason = null
    pendingLeaseReasons.clear()
    return reason
  }

  function takePostLeaveReason(leaseID: string): VoiceLeaseRevocationReason | null {
    const reason = pendingLocalReason ?? pendingLeaseReasons.get(leaseID) ?? null
    pendingLocalReason = null
    pendingLeaseReasons.clear()
    return reason
  }

  async function revokeLease(leaseID: string, reason: VoiceLeaseRevocationReason): Promise<boolean> {
    if (state.value === 'JOINING' && !active.value) {
      pendingLeaseReasons.set(leaseID, reason)
      if (pendingLeaseReasons.size > 16) pendingLeaseReasons.delete(pendingLeaseReasons.keys().next().value!)
      return false
    }
    if (active.value?.leaseId !== leaseID) return false
    if (state.value === 'LEAVING') { pendingLeaseReasons.set(leaseID, reason); return false }
    state.value = 'LEAVING'
    screenViewer.stop()
    volume.stop()
    try {
      if (!await session.revoke(leaseID)) throw new Error('Не удалось завершить локальное media-подключение.')
      active.value = null
      context.refreshAudioProcessingDiagnostics()
      context.deafened.value = false
      context.microphoneMuted.value = false
      context.microphonePermissionDenied.value = false
      context.screenDiagnostics.value = unknownScreenDiagnostics()
      context.screenProfile.value = null
      context.screenState.value = 'IDLE'
      state.value = 'ERROR'
      error.value = voiceLeaseRevocationMessage(reason)
      return true
    } catch (cause) {
      state.value = 'ERROR'
      error.value = cause instanceof Error ? cause.message : 'Не удалось завершить локальное media-подключение.'
      return false
    }
  }

  async function disconnectLocal(reason: VoiceLeaseRevocationReason): Promise<boolean> {
    if (state.value === 'JOINING' && !active.value) { pendingLocalReason = reason; return true }
    if (state.value === 'LEAVING' && active.value) { pendingLocalReason = reason; return true }
    const leaseID = active.value?.leaseId
    return leaseID ? revokeLease(leaseID, reason) : false
  }

  return { disconnectLocal, revokeLease, takeJoinRevocation, takePostLeaveReason }
}
