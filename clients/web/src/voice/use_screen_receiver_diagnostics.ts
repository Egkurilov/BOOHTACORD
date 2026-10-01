import { onBeforeUnmount, ref, watch, type Ref } from 'vue'

import { compareScreenReceiverStats, type ScreenReceiverMetrics, type ScreenReceiverSnapshot } from './screen_receiver_diagnostics'
import { ScreenPacketLossWindow } from './screen_packet_loss'
import type { ScreenViewerCard } from './screen_viewer_types'

export function useScreenReceiverDiagnostics(selected: Ref<ScreenViewerCard | null>, ended: () => boolean) {
  const metrics = ref<ScreenReceiverMetrics | null>(null)
  const sampledAt = ref<number | null>(null)
  let previous: ScreenReceiverSnapshot | null = null
  const lossWindow = new ScreenPacketLossWindow()
  let generation = 0
  let timer: ReturnType<typeof setInterval> | null = null
  let sampling = false

  async function sample(card: ScreenViewerCard, version: number): Promise<void> {
    if (sampling || !card.readReceiverStats) return
    sampling = true
    try {
      const current = await card.readReceiverStats()
      if (version !== generation) return
      if (!current) { metrics.value = null; sampledAt.value = null; previous = null; lossWindow.clear(); return }
      const packetLossPercent = lossWindow.add(current)
      metrics.value = { ...compareScreenReceiverStats(previous, current), packetLossPercent, packetLossWindowMs: lossWindow.durationMs }
      sampledAt.value = Date.now()
      previous = current
    } catch {
      if (version === generation) { metrics.value = null; sampledAt.value = null; previous = null; lossWindow.clear() }
    } finally {
      if (version === generation) sampling = false
    }
  }

  function restart(): void {
    generation += 1
    if (timer) clearInterval(timer)
    timer = null
    sampling = false
    previous = null
    lossWindow.clear()
    metrics.value = null
    sampledAt.value = null
    const card = selected.value
    if (!card?.readReceiverStats || ended()) return
    const version = generation
    void sample(card, version)
    timer = setInterval(() => { void sample(card, version) }, 2000)
  }

  watch([() => selected.value?.id, () => selected.value?.readReceiverStats, ended], restart, { immediate: true })
  onBeforeUnmount(() => { generation += 1; if (timer) clearInterval(timer) })
  return { metrics, sampledAt }
}
