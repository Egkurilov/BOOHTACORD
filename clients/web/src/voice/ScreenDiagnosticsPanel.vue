<script setup lang="ts">
import { computed } from 'vue'

import type { ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenProfile } from './livekit_gateway'

const props = defineProps<{ diagnostics: ScreenDiagnostics; profile: ScreenProfile | null }>()
const emit = defineEmits<{ refresh: [] }>()

const target = computed(() => ({
  P720_15: '720p · 15 FPS', P720_30: '720p · 30 FPS', P720_60: '720p · 60 FPS',
  P1080_15: '1080p · 15 FPS', P1080_30: '1080p · 30 FPS', P1080_60: '1080p · 60 FPS',
  P1440_15: '1440p · 15 FPS', P1440_30: '1440p · 30 FPS', P1440_60: '1440p · 60 FPS',
}[props.profile ?? 'P1080_30']))
const measured = computed(() => props.diagnostics.measured
  ? `${props.diagnostics.measured.width} × ${props.diagnostics.measured.height}${props.diagnostics.measured.framesPerSecond ? ` · ${props.diagnostics.measured.framesPerSecond} FPS` : ''}`
  : 'нет данных от браузера/SDK')
const audioTrack = computed(() => ({ PRESENT: 'есть', ABSENT: 'нет', UNKNOWN: 'неизвестно' }[props.diagnostics.audioTrack]))
const quality = computed(() => ({ EXCELLENT: 'отличное', GOOD: 'хорошее', POOR: 'низкое', LOST: 'потеряно', UNKNOWN: 'нет данных' }[props.diagnostics.connectionQuality]))
const source = computed(() => ({ ACTIVE: 'активен', ENDED: 'завершён', UNKNOWN: 'неизвестно' }[props.diagnostics.source]))
const layers = computed(() => (props.diagnostics.layers ?? []).map(layer => ({
  label: `${layer.rid ?? 'без RID'} · ${layer.codec ?? 'кодек неизвестен'} · ${layer.frameWidth ?? '?'} × ${layer.frameHeight ?? '?'}`,
  state: ({ ACTIVE: 'активен', INACTIVE: 'неактивен', STALE: 'устарел', UNKNOWN: 'нет данных' } as const)[layer.state],
  fps: layer.framesPerSecond === null ? 'нет данных' : `${layer.framesPerSecond.toFixed(1)} FPS`,
  bitrate: layer.bitrateBps === null ? 'нет данных' : `${Math.round(layer.bitrateBps / 1000)} кбит/с`,
  retransmitted: layer.retransmittedBps === null ? 'нет данных' : `${Math.round(layer.retransmittedBps / 1000)} кбит/с`,
  loss: layer.packetLossPercent === null ? 'нет данных' : `${layer.packetLossPercent.toFixed(2)}%`,
  control: `NACK ${layer.nackPerSecond?.toFixed(1) ?? '—'} · PLI ${layer.pliPerSecond?.toFixed(1) ?? '—'} · FIR ${layer.firPerSecond?.toFixed(1) ?? '—'}`,
  encode: layer.encodeMsPerFrame === null ? 'encode: нет данных' : `encode ${layer.encodeMsPerFrame.toFixed(2)} мс/кадр`,
})))
const technical = computed(() => [
  `Bitrate: ${props.diagnostics.bitrateBps === undefined ? 'нет данных' : `${Math.round(props.diagnostics.bitrateBps / 1000)} кбит/с`}`,
  `Потери: ${props.diagnostics.packetsLost ?? 'нет данных'}`,
  `RTT: ${props.diagnostics.roundTripTimeMs === undefined ? 'нет данных' : `${props.diagnostics.roundTripTimeMs} мс`}`,
  `Адаптация: ${props.diagnostics.adaptationReason ?? 'не сообщена'}`,
].join(' · '))
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
  <details v-if="layers.length">
    <summary>Слои видеопотока</summary>
    <ul><li v-for="layer in layers" :key="layer.label">{{ layer.label }} · {{ layer.state }} · {{ layer.fps }} · {{ layer.bitrate }} · повторы {{ layer.retransmitted }} · потери {{ layer.loss }} · {{ layer.control }} · {{ layer.encode }}</li></ul>
  </details>
  <button class="voice-join" type="button" @click="emit('refresh')">Обновить измерения</button>
</template>
