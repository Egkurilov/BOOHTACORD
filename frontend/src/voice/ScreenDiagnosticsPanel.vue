<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted } from 'vue'

import type { ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenProfile } from './livekit_gateway'
import { buildSenderScreenReport, startScreenClientReporting, webPlatform } from './screen_client_reporter'

const props = defineProps<{ diagnostics: ScreenDiagnostics; profile: ScreenProfile | null }>()
const emit = defineEmits<{ refresh: [] }>()

const target = computed(() => ({
  P720_30: '720p · 30 FPS', P720_60: '720p · 60 FPS', P1080_30: '1080p · 30 FPS', P1080_60: '1080p · 60 FPS',
}[props.profile ?? 'P1080_60']))
const measured = computed(() => props.diagnostics.measured
  ? `${props.diagnostics.measured.width} × ${props.diagnostics.measured.height}${props.diagnostics.measured.framesPerSecond ? ` · ${props.diagnostics.measured.framesPerSecond} FPS` : ''}`
  : 'нет данных от браузера/SDK')
const audioTrack = computed(() => ({ PRESENT: 'есть', ABSENT: 'нет', UNKNOWN: 'неизвестно' }[props.diagnostics.audioTrack]))
const quality = computed(() => ({ EXCELLENT: 'отличное', GOOD: 'хорошее', POOR: 'низкое', LOST: 'потеряно', UNKNOWN: 'нет данных' }[props.diagnostics.connectionQuality]))
const source = computed(() => ({ ACTIVE: 'активен', ENDED: 'завершён', UNKNOWN: 'неизвестно' }[props.diagnostics.source]))
const technical = computed(() => [
  `Bitrate: ${props.diagnostics.bitrateBps === undefined ? 'нет данных' : `${Math.round(props.diagnostics.bitrateBps / 1000)} кбит/с`}`,
  `Потери: ${props.diagnostics.packetsLost ?? 'нет данных'}`,
  `RTT: ${props.diagnostics.roundTripTimeMs === undefined ? 'нет данных' : `${props.diagnostics.roundTripTimeMs} мс`}`,
  `Адаптация: ${props.diagnostics.adaptationReason ?? 'не сообщена'}`,
].join(' · '))
let stopReporting: (() => void) | null = null
let refreshTimer: ReturnType<typeof setInterval> | null = null
onMounted(() => {
  const platform = webPlatform(navigator.userAgent)
  stopReporting = startScreenClientReporting(() => buildSenderScreenReport(platform, props.diagnostics), () => document.visibilityState === 'visible')
  refreshTimer = setInterval(() => { if (document.visibilityState === 'visible') emit('refresh') }, 2000)
})
onBeforeUnmount(() => { stopReporting?.(); if (refreshTimer) clearInterval(refreshTimer) })
</script>

<template>
  <p>Демонстрация идёт. Цель: {{ target }}. Измерено: {{ measured }}.</p>
  <dl class="screen-diagnostics">
    <div><dt>Аудиодорожка</dt><dd>{{ audioTrack }}</dd></div>
    <div><dt>Качество связи</dt><dd>{{ quality }}</dd></div>
    <div><dt>Источник</dt><dd>{{ source }}</dd></div>
  </dl>
  <details>
    <summary>Технические данные</summary>
    <p>{{ technical }}</p>
  </details>
  <button class="voice-join" type="button" @click="emit('refresh')">Обновить измерения</button>
</template>
