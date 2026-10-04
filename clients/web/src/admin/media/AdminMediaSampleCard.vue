<script setup lang="ts">
import type { AdminScreenSample } from './admin_media_client'

defineProps<{ sample: AdminScreenSample }>()
const platforms: Record<AdminScreenSample['platform'], string> = {
  ios_web: 'iPhone/iPad · браузер', android_web: 'Android · браузер', desktop_web: 'ПК · браузер',
  ios_native: 'iPhone/iPad · приложение', windows_native: 'Windows · приложение', macos_native: 'macOS · приложение',
  android_native: 'Android · приложение', desktop_native: 'ПК · приложение',
}
const states: Record<AdminScreenSample['state'], string> = {
  waiting_subscription: 'Ожидает видеодорожку', waiting_first_frame: 'Ожидает первый кадр',
  playing: 'Воспроизводит', stalled: 'Кадры остановились',
}
const value = (number: number | undefined, unit: string) => number === undefined ? 'Нет данных' : `${number} ${unit}`
</script>

<template>
  <article class="admin-media-sample">
    <header><strong>{{ platforms[sample.platform] }} · {{ sample.direction === 'sender' ? 'отправка' : 'приём' }}</strong>
      <time :datetime="sample.sampled_at_utc">{{ new Date(sample.sampled_at_utc).toLocaleTimeString('ru-RU') }}</time></header>
    <p>{{ states[sample.state] }} · Профиль не передан</p>
    <div class="admin-media-stages">
      <div><span>Отправка</span><strong>{{ sample.direction === 'sender' ? value(sample.encoded_fps, 'FPS') : 'Нет данных' }}</strong></div>
      <div><span>Приём</span><strong>{{ sample.direction === 'receiver' && sample.frame_width && sample.frame_height ? `${sample.frame_width} × ${sample.frame_height}` : 'Нет данных' }}</strong></div>
      <div><span>Декодирование</span><strong>{{ sample.direction === 'receiver' ? value(sample.decoded_fps, 'FPS') : 'Нет данных' }}</strong></div>
      <div><span>Показ</span><strong>{{ sample.direction === 'receiver' ? value(sample.presented_fps, 'FPS') : 'Нет данных' }}</strong></div>
    </div>
    <details><summary>Дополнительные измерения</summary><p>Битрейт · {{ value(sample.bitrate_kbps, 'кбит/с') }} · Jitter · {{ value(sample.jitter_ms, 'мс') }}</p>
      <p>Потеряно пакетов · {{ sample.packets_lost ?? 'Нет данных' }} · Пропущено кадров · {{ sample.dropped_frames ?? 'Нет данных' }} · RTT · {{ value(sample.rtt_ms, 'мс') }}</p></details>
  </article>
</template>
