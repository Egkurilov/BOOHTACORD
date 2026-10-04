import { onScopeDispose, shallowRef, watch, type Ref } from 'vue'
import type { ActiveVoiceSession } from '../voice_session'
import type { VoiceAudioDiagnostics } from './model'
import { createAudioTelemetryReporter } from './telemetry'
export function monitorAudioSamples<T>(read: () => Promise<T>, update: (value: T | null) => void): () => void {
  let disposed = false, busy = false
  const sample = async () => {
    if (disposed || busy) return
    busy = true
    try { const value = await read(); if (!disposed) update(value) }
    catch { if (!disposed) update(null) }
    finally { busy = false }
  }
  const timer = setInterval(() => { void sample() }, 2000)
  void sample()
  return () => { disposed = true; clearInterval(timer) }
}
export function installAudioDiagnostics(active: Ref<ActiveVoiceSession | null>, phase: Ref<string>) {
  const diagnostics = shallowRef<VoiceAudioDiagnostics | null>(null)
  let stop: (() => void) | undefined
  watch([active, phase], ([current, state]) => {
    stop?.(); stop = undefined; diagnostics.value = null
    const read = current?.room.readVoiceAudioDiagnostics
    if (!current || !read || !['CONNECTED', 'LISTENER'].includes(state)) return
    const report = createAudioTelemetryReporter()
    stop = monitorAudioSamples(read.bind(current.room), (value) => {
      if (active.value !== current || !['CONNECTED', 'LISTENER'].includes(phase.value)) return
      diagnostics.value = value
      if (value) report(value)
    })
  }, { immediate: true, flush: 'sync' })
  onScopeDispose(() => stop?.())
  return diagnostics
}
