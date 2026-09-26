<script setup lang="ts">
import { computed } from 'vue'

import type { ScreenReceiverMetrics } from './screen_receiver_diagnostics'

const props = defineProps<{
  actualVideoQuality: string
  hasAudio: boolean
  isLocal: boolean
  metrics: ScreenReceiverMetrics | null
  sampledAt: number | null
}>()
const status = computed(() => props.sampledAt === null ? 'Нет свежих данных' : `Измерено в ${new Date(props.sampledAt).toLocaleTimeString('ru-RU')}`)
const value = (number: number | null | undefined, suffix: string) => number === null || number === undefined ? 'Нет данных' : `${number} ${suffix}`
</script>

<template>
  <details class="stream-diagnostics">
    <summary :title="status"><span class="stream-diagnostics-badge" aria-hidden="true"></span><span class="gc-sr-only">{{ status }}</span></summary>
    <div class="stream-diagnostics-panel"><dl>
      <div><dt>Целевой профиль</dt><dd>Не передан источником</dd></div>
      <div><dt>Сейчас у зрителя</dt><dd>{{ actualVideoQuality }}</dd></div>
      <div><dt>Декодировано</dt><dd>{{ value(metrics?.decodedFps, 'FPS') }}</dd></div>
      <div><dt>Получено</dt><dd>{{ value(metrics?.bitrateKbps, 'кбит/с') }}</dd></div>
      <div><dt>Потеряно пакетов</dt><dd>{{ metrics?.packetsLost ?? 'Нет данных' }}</dd></div>
      <div><dt>Пропущено кадров за интервал</dt><dd>{{ metrics?.droppedFrames ?? 'Нет данных' }}</dd></div>
      <div><dt>Jitter</dt><dd>{{ value(metrics?.jitterMs, 'мс') }}</dd></div>
      <div><dt>RTT</dt><dd>Нет данных от приёмника</dd></div>
      <div><dt>Аудиодорожка</dt><dd>{{ isLocal ? 'Предпросмотр без звука' : hasAudio ? 'Аудиодорожка есть' : 'Аудиодорожки нет' }}</dd></div>
      <div><dt>Последнее измерение</dt><dd>{{ status }}</dd></div>
    </dl></div>
  </details>
</template>
