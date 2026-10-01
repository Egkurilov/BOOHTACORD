<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { listAuditEvents, type AuditEvent } from '../identity/admin_directory_client'
import { presentAuditEvent } from './audit_event_display'

const events = ref<AuditEvent[]>([]); const cursor = ref<string | undefined>(); const loading = ref(false); const error = ref<string | null>(null)
const displayedEvents = computed(() => events.value.map((event) => ({ id: event.id, createdAt: event.created_at, ...presentAuditEvent(event) })))
async function load(before?: string): Promise<void> {
  loading.value = true; error.value = null
  try { const page = await listAuditEvents(before); events.value = before ? [...events.value, ...page.events] : page.events; cursor.value = page.next_cursor }
  catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить аудит.' } finally { loading.value = false }
}
onMounted(() => { void load() })
</script>

<template>
  <section class="admin-audit" aria-labelledby="admin-audit-title">
    <header class="admin-section-heading"><div><h2 id="admin-audit-title">Аудит</h2><p>События управления без содержимого сообщений</p></div><button type="button" :disabled="loading" @click="load()">Обновить</button></header>
    <p v-if="loading && !events.length" class="state" aria-live="polite">Загружаем аудит…</p>
    <p v-else-if="!loading && !events.length && !error" class="state">Записей пока нет.</p>
    <ol v-if="displayedEvents.length" class="audit-event-list">
      <li v-for="event in displayedEvents" :key="event.id"><div><strong>{{ event.title }}</strong><time :datetime="event.createdAt">{{ new Date(event.createdAt).toLocaleString('ru-RU') }}</time></div><small>Инициатор · {{ event.actor }}</small><small v-if="event.target">Объект · {{ event.target }}</small></li>
    </ol>
    <button v-if="cursor" class="admin-more" type="button" :disabled="loading" @click="load(cursor)">Показать более ранние</button>
    <p v-if="error" class="admin-error" role="alert">{{ error }}</p>
  </section>
</template>
