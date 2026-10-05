import type { Ref } from 'vue'
import type { ActiveVoiceSession,VoiceSession } from '../voice_session'
import type { VoiceJoinMode } from '../livekit_gateway'
import type { VoiceDisconnectState } from '../disconnect_notice/state'
import type { VoiceConnectionState } from './types'
import { voiceLeaseRevocationMessage } from '../voice_lease_revocation_reason'
import type { createVoiceConnectionRevocation } from '../voice_connection_revocation'
import { VoiceRequestError } from '../admission_client'
import type { createControllerOwnership } from '../controller_ownership/state'
interface JoinContext {
 session:VoiceSession;terminal:VoiceDisconnectState;revocation:ReturnType<typeof createVoiceConnectionRevocation>
 active:Ref<ActiveVoiceSession|null>;state:Ref<VoiceConnectionState>;error:Ref<string|null>;deafened:Ref<boolean>
 microphoneMuted:Ref<boolean>;microphonePermissionDenied:Ref<boolean>;canJoin:Ref<boolean>;transferRequired:Ref<boolean>
 screenViewer:{start():void};volume:{start():Promise<void>};refreshAudioProcessingDiagnostics():void
 ownership:ReturnType<typeof createControllerOwnership>;transferChannelId:Ref<string|null>;transferJoinMode:Ref<VoiceJoinMode>
}
export function createConnectionJoin(context:JoinContext) {
 const {session,terminal,revocation,active,state,error,deafened,microphoneMuted,microphonePermissionDenied,canJoin,transferRequired,screenViewer,volume,refreshAudioProcessingDiagnostics}=context
  async function join(channelId: string, transfer = false, joinMode: VoiceJoinMode = 'with-microphone'): Promise<void> {
    if (!canJoin.value) return

    terminal.reset(); revocation.resetPending()
    const generation = terminal.generation
    state.value = 'JOINING'
    error.value = null
    transferRequired.value = false
    context.transferChannelId.value=null;context.transferJoinMode.value=joinMode
    try {
      if(!await context.ownership.claim(channelId,transfer)) throw new VoiceRequestError(409,'ORIGIN_MEDIA_BUSY',context.ownership.otherChannelId.value ?? undefined)
      if(generation!==terminal.generation){await context.ownership.release();return}
      const joined = await session.join(channelId, transfer, joinMode)
      if (generation !== terminal.generation) { await session.revoke(joined.leaseId); state.value = 'IDLE'; error.value = null; return }
      active.value = joined
      terminal.bind(active.value.leaseId, active.value.channelId)
      const revokedReason = revocation.takeJoinRevocation(active.value.leaseId)
      if (revokedReason) { await revocation.revokeLease(active.value.leaseId, revokedReason); return }
      refreshAudioProcessingDiagnostics()
      screenViewer.start()
      await volume.start()
      if (!active.value || terminal.notice.value?.source === 'server') return
      deafened.value = false
      microphoneMuted.value = active.value.microphone === 'MUTED'
      microphonePermissionDenied.value = active.value.microphone === 'LISTENER_PERMISSION_DENIED'
      state.value = active.value.microphone === 'PUBLISHED' ? 'CONNECTED' : 'LISTENER'
    } catch (cause) {
      if (generation !== terminal.generation) { state.value = 'IDLE'; error.value = null; return }
      const cancelledReason = revocation.takeJoinRevocation(terminal.leaseID ?? '')
      active.value = null
      deafened.value = false
      microphoneMuted.value = false
      microphonePermissionDenied.value = false
      state.value = 'ERROR'
      transferRequired.value = cause instanceof VoiceRequestError && cause.status===409 && ['ACTIVE_VOICE_LEASE','ORIGIN_MEDIA_BUSY'].includes(cause.code ?? '')
      context.transferChannelId.value=transferRequired.value && cause instanceof VoiceRequestError ? cause.activeChannelId ?? null : null
      if (cancelledReason && terminal.leaseID) terminal.server(terminal.leaseID, cancelledReason)
      error.value = terminal.notice.value?.message ?? (cancelledReason ? voiceLeaseRevocationMessage(cancelledReason) : cause instanceof Error ? cause.message : 'Не удалось подключиться к голосовому каналу.')
    } finally {if(!active.value) await context.ownership.release()}
  }

 return {join}
}
