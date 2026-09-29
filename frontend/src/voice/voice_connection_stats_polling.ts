import type { VoiceConnectionStats } from './voice_connection_quality'

export function monitorVoiceConnectionStats(
  read: () => Promise<VoiceConnectionStats>,
  publish: (stats: VoiceConnectionStats) => void,
  failed: () => void = () => undefined,
  intervalMs = 2000,
): () => void {
  let disposed = false
  let inFlight = false
  const sample = async (): Promise<void> => {
    if (disposed || inFlight) return
    inFlight = true
    try {
      const stats = await read()
      if (!disposed) publish(stats)
    } catch {
      if (!disposed) failed()
    } finally {
      inFlight = false
    }
  }
  void sample()
  const timer = globalThis.setInterval(() => { void sample() }, intervalMs)
  return () => {
    disposed = true
    globalThis.clearInterval(timer)
  }
}
