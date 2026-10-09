<script setup lang="ts">
import { computed, onActivated, onBeforeUnmount, onDeactivated, onMounted, ref } from 'vue'
import { listAdminScreenMetrics, type AdminScreenSample } from './admin_media_client'
import AdminMediaSampleCard from './AdminMediaSampleCard.vue'
import { isFreshSample, selectAdminMediaState } from './admin_media_state'

const samples = ref<AdminScreenSample[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const now = ref(Date.now())
const lastSuccessfulAt = ref<number | null>(null)
const lastSeenAt = ref<number | null>(null)
const state = computed(() => selectAdminMediaState(samples.value, now.value, lastSeenAt.value, error.value))
const freshSamples = computed(() => samples.value.filter((sample) => isFreshSample(sample, now.value)))
let timer: ReturnType<typeof setInterval> | null = null

async function load(): Promise<void> {
  if (loading.value) return
  loading.value = true
  error.value = null
  try {
    const received = await listAdminScreenMetrics()
    now.value = Date.now()
    samples.value = received
    lastSuccessfulAt.value = now.value
    if (received.length) lastSeenAt.value = Math.max(lastSeenAt.value ?? 0, ...received.map(({ sampled_at_utc }) => Date.parse(sampled_at_utc)))
    error.value = null
  } catch { error.value = 'Не удалось загрузить показатели.' }
  finally { loading.value = false }
}
function startMonitoring(): void {
  if (timer) return
  void load()
  timer = setInterval(() => { now.value = Date.now(); if (document.visibilityState === 'visible') void load() }, 5000)
}
function stopMonitoring(): void { if (timer) clearInterval(timer); timer = null }
onMounted(startMonitoring)
onActivated(startMonitoring)
onDeactivated(stopMonitoring)
onBeforeUnmount(stopMonitoring)
</script>

<template>
  <section class="admin-media-diagnostics" aria-labelledby="admin-media-title">
    <header class="admin-section-heading"><div><h2 id="admin-media-title">Показатели трансляций</h2><p>Последние 60 секунд · без имён и идентификаторов участников</p></div>
      <button type="button" :disabled="loading" @click="load()">{{ loading ? 'Проверяем…' : 'Обновить' }}</button></header>
    <div class="admin-media-freshness" role="status" aria-live="polite"><strong>{{ loading ? lastSuccessfulAt ? 'Обновляем показатели; предыдущий ответ сохранён' : 'Загружаем показатели' : state.kind === 'populated' ? 'Есть измерения' : state.kind === 'stale' ? 'Данные устарели' : state.kind === 'error' ? 'Ошибка обновления' : 'Нет данных' }}</strong>
      <span>Свежих отчётов: {{ state.freshCount }}</span>
      <span v-if="lastSuccessfulAt">Успешно обновлено: {{ new Date(lastSuccessfulAt).toLocaleTimeString('ru-RU') }}</span></div>
    <p v-if="error" class="admin-error" role="alert">{{ error }} Повторите обновление; прежние измерения нельзя считать текущими.</p>
    <div v-if="state.kind === 'empty' && !loading" class="admin-media-empty">
      <h3>Как получить отчёты</h3><ol><li>Запустите трансляцию вручную.</li><li>Откройте её на другом клиенте.</li><li>Подождите до 60 секунд и обновите показатели.</li></ol>
    </div>
    <p v-if="state.kind === 'stale'" class="admin-media-stale">Свежих отчётов нет. Последнее измерение: {{ lastSeenAt ? new Date(lastSeenAt).toLocaleString('ru-RU') : 'время неизвестно' }}.</p>
    <div v-if="state.kind === 'populated'" class="admin-media-samples">
      <AdminMediaSampleCard v-for="(sample, index) in freshSamples" :key="`${sample.platform}:${sample.direction}:${sample.sampled_at_utc}:${index}`" :sample="sample" />
    </div>
    <details class="admin-media-explain"><summary>Как читать показатели</summary>
      <p>Данные сообщают сами клиенты. Они не подтверждают содержимое кадра, аппаратный профиль или причину неполадки. Отсутствие отчётов не доказывает, что сеть или сбор телеметрии работают правильно.</p>
    </details>
  </section>
</template>
