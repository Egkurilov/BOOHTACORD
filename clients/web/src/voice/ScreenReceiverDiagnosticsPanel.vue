<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

import { placeScreenDiagnostics } from './screen_diagnostics_placement'
import type { ScreenReceiverMetrics } from './screen_receiver_diagnostics'

const props = defineProps<{
  actualVideoQuality: string
  hasAudio: boolean
  isLocal: boolean
  metrics: ScreenReceiverMetrics | null
  sampledAt: number | null
  targetProfile?: string
  participantName?: string
  presentedFps?: number | null
}>()
const status = computed(() => props.sampledAt === null ? 'Нет свежих данных' : `Измерено в ${new Date(props.sampledAt).toLocaleTimeString('ru-RU')}`)
const value = (number: number | null | undefined, suffix: string) => number === null || number === undefined ? 'Нет данных' : `${number} ${suffix}`
const percent = (number: number | null | undefined) => number === null || number === undefined ? 'Нет данных' : `${new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 }).format(number)} %`
const profile = computed(() => props.targetProfile?.match(/^P(720|1080|1440)_(15|30|60)$/)?.slice(1).join('p / ').replace(/$/, ' FPS') ?? props.targetProfile ?? 'Нет данных от источника')
const bitrate = computed(() => props.metrics?.bitrateKbps == null ? 'Нет данных' : `${new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 }).format(props.metrics.bitrateKbps / 1000)} Мбит/с`)
const diagnostics = ref<HTMLDetailsElement | null>(null)
const isOpen = ref(false)
const mobile = ref(false)
const panel = ref<HTMLDivElement | null>(null)
let placementFrame = 0

function updatePlacement(): void {
  const root = diagnostics.value
  if (!root?.open) return
  cancelAnimationFrame(placementFrame)
  placementFrame = requestAnimationFrame(() => {
    const popover = panel.value
    if (!popover) return
    const summary = root.querySelector('summary')
    if (!summary || !root.open) return
    const rect = summary.getBoundingClientRect()
    const result = placeScreenDiagnostics({
      summaryLeft: rect.left,
      summaryRight: rect.right,
      summaryTop: rect.top,
      summaryBottom: rect.bottom,
      panelHeight: popover.scrollHeight,
      panelWidth: popover.getBoundingClientRect().width,
      viewportWidth: window.innerWidth,
      viewportHeight: window.innerHeight,
      alignLeft: window.innerWidth <= 1100,
    })
    root.dataset.placement = result.placement
    popover.style.maxHeight = `${result.maxHeight}px`
    popover.style.top = `${result.top}px`
    popover.style.left = `${result.left}px`
  })
}
function close(): void {
  if (diagnostics.value) diagnostics.value.open = false
  isOpen.value = false
  diagnostics.value?.querySelector('summary')?.focus()
}
function handleToggle(): void {
  isOpen.value = Boolean(diagnostics.value?.open)
  if (isOpen.value) void nextTick(() => panel.value?.querySelector<HTMLButtonElement>('header button')?.focus())
  updatePlacement()
}
function handleKeydown(event: KeyboardEvent): void {
  if (!isOpen.value) return
  if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); close() }
  else if (mobile.value && event.key === 'Tab') { event.preventDefault(); panel.value?.querySelector<HTMLButtonElement>('header button')?.focus() }
}
function handleResize(): void { mobile.value = window.innerWidth <= 600; updatePlacement() }

onMounted(() => {
  handleResize()
  window.addEventListener('resize', handleResize)
  window.addEventListener('scroll', updatePlacement, true)
  window.addEventListener('keydown', handleKeydown, true)
})
onBeforeUnmount(() => {
  cancelAnimationFrame(placementFrame)
  window.removeEventListener('resize', handleResize)
  window.removeEventListener('scroll', updatePlacement, true)
  window.removeEventListener('keydown', handleKeydown, true)
})
</script>

<template>
  <details ref="diagnostics" class="stream-diagnostics" @toggle="handleToggle">
    <summary :title="status" aria-label="Статистика" class="stream-tool-button"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 19V8m5 11V4m5 15v-9m5 9V6M2 21h20"/></svg><span class="gc-sr-only">Статистика</span></summary>
    <Teleport v-if="isOpen" to="body">
    <button type="button" class="stream-diagnostics-backdrop" aria-label="Закрыть статистику" @click="close" />
    <div ref="panel" class="stream-diagnostics-panel" role="dialog" aria-label="Статистика трансляции" :aria-modal="mobile ? 'true' : undefined"><header><h2>Статистика</h2><button type="button" aria-label="Закрыть статистику" @click="close">×</button></header><p>{{ participantName ? `Экран ${participantName}` : 'Трансляция' }} · {{ status }}</p><dl>
      <div><dt>Профиль</dt><dd>{{ profile }}</dd></div>
      <div><dt>Сейчас у зрителя</dt><dd>{{ actualVideoQuality }}</dd></div>
      <div><dt>Декодирование</dt><dd>{{ value(metrics?.decodedFps, 'FPS') }}</dd></div>
      <div><dt>Показ кадров</dt><dd>{{ value(presentedFps, 'FPS') }}</dd></div>
      <div><dt>Битрейт</dt><dd>{{ bitrate }}</dd></div>
      <div><dt>Потери пакетов за 10 с</dt><dd>{{ percent(metrics?.packetLossPercent) }}</dd></div>
      <div><dt>Джиттер</dt><dd>{{ value(metrics?.jitterMs, 'мс') }}</dd></div>
      <div><dt>RTT</dt><dd>Нет данных от приёмника</dd></div>
      <div><dt>Звук трансляции</dt><dd>{{ isLocal ? 'Предпросмотр без звука' : hasAudio ? 'Аудиодорожка есть' : 'Аудиодорожки нет' }}</dd></div>
    </dl><small class="stream-diagnostics-footnote">Текущее качество у зрителя: {{ actualVideoQuality }}</small></div>
    </Teleport>
  </details>
</template>
