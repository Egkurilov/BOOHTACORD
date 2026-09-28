<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'

import { listAdminScreenMetrics, type AdminScreenSample } from './admin_media_client'

const samples = ref<AdminScreenSample[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
let timer: ReturnType<typeof setInterval> | null = null
const platforms: Record<AdminScreenSample['platform'], string> = {
  ios_web: 'iPhone/iPad · браузер', android_web: 'Android · браузер', desktop_web: 'ПК · браузер',
  android_native: 'Android · приложение', desktop_native: 'ПК · приложение',
}
const states: Record<AdminScreenSample['state'], string> = {
  waiting_subscription: 'Ожидает видеодорожку', waiting_first_frame: 'Ожидает первый кадр',
  playing: 'Воспроизводит', stalled: 'Кадры остановились',
}
const value = (number: number | undefined, unit: string) => number === undefined ? 'Нет данных' : `${number} ${unit}`

async function load(): Promise<void> {
  if (loading.value) return
  loading.value = true
  try { samples.value = await listAdminScreenMetrics(); error.value = null }
  catch { error.value = 'Не удалось загрузить показатели.' }
  finally { loading.value = false }
}
onMounted(() => { void load(); timer = setInterval(() => { if (document.visibilityState === 'visible') void load() }, 5000) })
onBeforeUnmount(() => { if (timer) clearInterval(timer) })
</script>

<template>
  <section class="admin-audit" aria-labelledby="admin-media-title">
    <header class="admin-section-heading"><div><h2 id="admin-media-title">Показатели трансляций</h2><p>Последние 60 секунд · без имён и идентификаторов участников</p></div><button type="button" :disabled="loading" @click="load()">Обновить</button></header>
    <p class="state">Сравните размеры кадра и FPS отправки, приёма и показа: так проще найти участок потери разрешения или кадров. Данные сообщают сами клиенты; они не подтверждают содержимое кадра или аппаратный профиль.</p>
    <p v-if="error" class="admin-error" role="alert">{{ error }}</p>
    <p v-else-if="!samples.length" class="state" role="status">Свежих показателей пока нет. Откройте демонстрацию у зрителя.</p>
    <ol v-else class="audit-event-list">
      <li v-for="sample in samples" :key="`${sample.platform}:${sample.direction}`">
        <div><strong>{{ platforms[sample.platform] }} · {{ sample.direction === 'sender' ? 'отправка' : 'приём' }}</strong><time :datetime="sample.sampled_at_utc">{{ new Date(sample.sampled_at_utc).toLocaleTimeString('ru-RU') }}</time></div>
        <small>Состояние · {{ states[sample.state] }}</small>
        <small>Размер кадра · {{ sample.frame_width && sample.frame_height ? `${sample.frame_width} × ${sample.frame_height}` : 'Нет данных' }}</small>
        <small>Отправлено · {{ value(sample.encoded_fps, 'FPS') }} · Декодировано · {{ value(sample.decoded_fps, 'FPS') }} · Показано · {{ value(sample.presented_fps, 'FPS') }}</small>
        <small>Битрейт · {{ value(sample.bitrate_kbps, 'кбит/с') }} · Потеряно пакетов · {{ sample.packets_lost ?? 'Нет данных' }} · Пропущено кадров · {{ sample.dropped_frames ?? 'Нет данных' }} · Jitter · {{ value(sample.jitter_ms, 'мс') }} · RTT · {{ value(sample.rtt_ms, 'мс') }}</small>
      </li>
    </ol>
  </section>
</template>
