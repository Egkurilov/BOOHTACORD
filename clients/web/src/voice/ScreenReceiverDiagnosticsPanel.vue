<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'

import { placeScreenDiagnostics } from './screen_diagnostics_placement'
import type { ScreenReceiverMetrics } from './screen_receiver_diagnostics'
import { screenCaptureLabel, screenEncodingLabel, screenModeLabel, screenTargetLabel, screenTargetSourceLabel, type ScreenProfileSource } from './screen_profile_metadata/presentation'
import type { ScreenShareDescriptorV1 } from './screen_profile_metadata/types'
import { screenSampleAge } from './screen_profile_metadata/profile'

const props = defineProps<{
  actualVideoQuality: string
  hasAudio: boolean
  isLocal: boolean
  metrics: ScreenReceiverMetrics | null
  sampledAt: number | null
  targetProfile?: string
  descriptor?: ScreenShareDescriptorV1
  profileSource?: ScreenProfileSource
  participantName?: string
  presentedFps?: number | null
}>()
const status = computed(() => props.sampledAt === null ? screenSampleAge(null) : `${new Date(props.sampledAt).toLocaleTimeString('ru-RU')} · ${screenSampleAge(props.sampledAt)}`)
const value = (number: number | null | undefined, suffix: string) => number === null || number === undefined ? 'Нет данных' : `${number} ${suffix}`
const percent = (number: number | null | undefined) => number === null || number === undefined ? 'Нет данных' : `${new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 2 }).format(number)} %`
const profile = computed(() => screenTargetLabel(props.descriptor?.requested_profile_id, props.targetProfile))
const profileSource = computed(() => screenTargetSourceLabel(props.profileSource))
const mode = computed(() => screenModeLabel(props.descriptor?.mode))
const capture = computed(() => screenCaptureLabel(props.descriptor))
const encoding = computed(() => screenEncodingLabel(props.descriptor))
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
    <summary :title="status" aria-label="Статистика" class="stream-tool-button"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20V4M4 20h17M8 16v-5M13 16V7M18 16v-9"/></svg><span class="gc-sr-only">Статистика</span></summary>
    <Teleport v-if="isOpen" to="body">
    <button type="button" class="stream-diagnostics-backdrop" aria-label="Закрыть статистику" @click="close" />
    <div ref="panel" class="stream-diagnostics-panel" role="dialog" aria-label="Статистика трансляции" :aria-modal="mobile ? 'true' : undefined"><header><h2>Статистика</h2><button type="button" aria-label="Закрыть статистику" @click="close">×</button></header><p>{{ participantName ? `Экран ${participantName}` : 'Трансляция' }} · {{ status }}</p><dl>
      <div><dt>Профиль</dt><dd>{{ profile }}</dd></div>
      <div><dt>Источник цели</dt><dd>{{ profileSource }}</dd></div>
      <div><dt>Сценарий</dt><dd>{{ mode }}</dd></div>
      <div><dt>Размер захвата отправителя</dt><dd>{{ capture }}</dd></div>
      <div><dt>Лимиты кодирования отправителя</dt><dd>{{ encoding }}</dd></div>
      <div><dt>Сейчас у зрителя</dt><dd>{{ actualVideoQuality }}</dd></div>
      <div><dt>Декодирование</dt><dd>{{ value(metrics?.decodedFps, 'FPS') }}</dd></div>
      <div><dt>Показ кадров</dt><dd>{{ value(presentedFps, 'FPS') }}</dd></div>
      <div><dt>Битрейт</dt><dd>{{ bitrate }}</dd></div>
      <div><dt>Потери пакетов за 10 с</dt><dd>{{ percent(metrics?.packetLossPercent) }}</dd></div>
      <div><dt>Джиттер</dt><dd>{{ value(metrics?.jitterMs, 'мс') }}</dd></div>
      <div><dt>RTT</dt><dd>Нет данных от приёмника</dd></div>
      <div><dt>Опубликованная аудиодорожка</dt><dd>{{ isLocal ? 'Предпросмотр без звука' : hasAudio ? 'Есть в LiveKit' : 'Нет в LiveKit' }}</dd></div>
    </dl><small class="stream-diagnostics-footnote">Текущее качество у зрителя: {{ actualVideoQuality }}</small></div>
    </Teleport>
  </details>
</template>
