import { shallowRef } from 'vue'
import { disconnectNotice, type VoiceDisconnectNotice } from './model'
import type { VoiceLeaseRevocationReason } from '../voice_lease_revocation_reason'
import { reportVoiceDisconnect } from './reporting'
export function createVoiceDisconnectState(report: (notice: VoiceDisconnectNotice) => void = reportVoiceDisconnect) {
  const notice = shallowRef<VoiceDisconnectNotice | null>(null)
  let lease: string | null = null, channel: string | null = null, reported = false, generation = 0
  function commit(): void {
    if (!notice.value || reported) return
    reported = true
    try { report(notice.value) } catch { /* Diagnostics cannot interrupt cleanup. */ }
  }
  function reset(): void { commit(); generation++; lease = channel = null; reported = false; notice.value = null }
  function bind(leaseID: string, channelID: string): void { lease = leaseID; channel = channelID }
  function server(leaseID: string, reason: VoiceLeaseRevocationReason): boolean {
    if (leaseID !== lease || !leaseID) return false
    if (notice.value?.source !== 'server') { notice.value = disconnectNotice(reason, 'server'); commit() }
    return true
  }
  function local(): void { if (notice.value?.source !== 'server') notice.value = disconnectNotice('VOLUNTARY_LEAVE', 'local') }
  function transport(): void { if (!notice.value) notice.value = disconnectNotice('TRANSPORT', 'transport') }
  function selectChannel(id: string): void { if (notice.value && channel !== id) reset() }
  return { notice, bind, server, local, transport, reset, selectChannel, get generation() { return generation }, get leaseID() { return lease } }
}
export type VoiceDisconnectState = ReturnType<typeof createVoiceDisconnectState>
