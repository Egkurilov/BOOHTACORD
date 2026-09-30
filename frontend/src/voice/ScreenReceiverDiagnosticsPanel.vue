<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import { placeScreenDiagnostics } from './screen_diagnostics_placement'
import type { ScreenReceiverMetrics } from './screen_receiver_diagnostics'

const props = defineProps<{
  actualVideoQuality: string
  hasAudio: boolean
  isLocal: boolean
  metrics: ScreenReceiverMetrics | null
  sampledAt: number | null
  targetProfile?: string
}>()
const status = computed(() => props.sampledAt === null ? 'Нет свежих данных' : `Измерено в ${new Date(props.sampledAt).toLocaleTimeString('ru-RU')}`)
const value = (number: number | null | undefined, suffix: string) => number === null || number === undefined ? 'Нет данных' : `${number} ${suffix}`
const percent = (number: number | null | undefined) => number === null || number === undefined ? 'Нет данных' : `${new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 }).format(number)} %`
const diagnostics = ref<HTMLDetailsElement | null>(null)
const panel = ref<HTMLDivElement | null>(null)
let placementFrame = 0

function updatePlacement(): void {
  const root = diagnostics.value
  const popover = panel.value
  if (!root?.open || !popover) return
  cancelAnimationFrame(placementFrame)
  placementFrame = requestAnimationFrame(() => {
    const summary = root.querySelector('summary')
    if (!summary || !root.open) return
    const rect = summary.getBoundingClientRect()
    const result = placeScreenDiagnostics({
      summaryTop: rect.top,
      summaryBottom: rect.bottom,
      panelHeight: popover.scrollHeight,
      viewportHeight: window.innerHeight,
    })
    root.dataset.placement = result.placement
    popover.style.maxHeight = `${result.maxHeight}px`
  })
}

onMounted(() => {
  window.addEventListener('resize', updatePlacement)
  window.addEventListener('scroll', updatePlacement, true)
})
onBeforeUnmount(() => {
  cancelAnimationFrame(placementFrame)
  window.removeEventListener('resize', updatePlacement)
  window.removeEventListener('scroll', updatePlacement, true)
})
</script>

<template>
  <details ref="diagnostics" class="stream-diagnostics" @toggle="updatePlacement">
    <summary :title="status"><span class="stream-diagnostics-badge" aria-hidden="true"></span><span>Статистика</span><span class="gc-sr-only">{{ status }}</span></summary>
    <div ref="panel" class="stream-diagnostics-panel"><dl>
      <div><dt>Профиль при запуске</dt><dd>{{ targetProfile ?? 'Нет данных от источника' }}</dd></div>
      <div><dt>Сейчас у зрителя</dt><dd>{{ actualVideoQuality }}</dd></div>
      <div><dt>Декодировано</dt><dd>{{ value(metrics?.decodedFps, 'FPS') }}</dd></div>
      <div><dt>Получено</dt><dd>{{ value(metrics?.bitrateKbps, 'кбит/с') }}</dd></div>
      <div><dt>Потери пакетов за 10 с</dt><dd>{{ percent(metrics?.packetLossPercent) }}</dd></div>
      <div><dt>Пропущено кадров за интервал</dt><dd>{{ metrics?.droppedFrames ?? 'Нет данных' }}</dd></div>
      <div><dt>Jitter</dt><dd>{{ value(metrics?.jitterMs, 'мс') }}</dd></div>
      <div><dt>RTT</dt><dd>Нет данных от приёмника</dd></div>
      <div><dt>Аудиодорожка</dt><dd>{{ isLocal ? 'Предпросмотр без звука' : hasAudio ? 'Аудиодорожка есть' : 'Аудиодорожки нет' }}</dd></div>
      <div><dt>Последнее измерение</dt><dd>{{ status }}</dd></div>
    </dl></div>
  </details>
</template>
