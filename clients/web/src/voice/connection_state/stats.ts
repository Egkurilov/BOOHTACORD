import { onScopeDispose,ref,watch,type Ref } from 'vue'
import type { ActiveVoiceSession } from '../voice_session'
import type { VoiceConnectionState } from './types'
import type { VoiceConnectionQuality } from '../voice_connection_quality'
import { installAudioDiagnostics } from '../audio_diagnostics/monitor'
import { monitorVoiceConnectionStats } from '../voice_connection_stats_polling'
import { createConnectionReporter } from '../report_media/connection'
export function createConnectionStats(active:Ref<ActiveVoiceSession|null>,state:Ref<VoiceConnectionState>) {
  const voiceAudioDiagnostics = installAudioDiagnostics(active, state)
  const connectionQuality = ref<VoiceConnectionQuality>('UNKNOWN')
  const pingMs = ref<number | null>(null)
  let stopVoiceStatsPolling: (() => void) | null = null
  watch([active, state], ([current, phase]) => {
    const readStats = current?.room.readVoiceConnectionStats
    stopVoiceStatsPolling?.()
    stopVoiceStatsPolling = null
    connectionQuality.value = 'UNKNOWN'
    pingMs.value = null
    if (!current || (phase !== 'CONNECTED' && phase !== 'LISTENER') || !readStats) return
    const reportConnection = createConnectionReporter()
    stopVoiceStatsPolling = monitorVoiceConnectionStats(readStats.bind(current.room), (stats) => {
      if (active.value !== current || (state.value !== 'CONNECTED' && state.value !== 'LISTENER')) return
      connectionQuality.value = stats.quality
      pingMs.value = stats.pingMs
      reportConnection(stats)
    }, () => {
      if (active.value !== current) return
      connectionQuality.value = 'UNKNOWN'
      pingMs.value = null
    })
  }, { immediate: true, flush: 'sync' })
  onScopeDispose(() => stopVoiceStatsPolling?.())
  return {voiceAudioDiagnostics,connectionQuality,pingMs}
}
