<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { listAuditEvents, type AuditEvent } from '../identity/admin_directory_client'

const events = ref<AuditEvent[]>([]); const cursor = ref<string | undefined>(); const loading = ref(false); const error = ref<string | null>(null)
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
    <ol v-if="events.length" class="audit-event-list">
      <li v-for="event in events" :key="event.id"><div><strong>{{ event.event_type }}</strong><time :datetime="event.created_at">{{ new Date(event.created_at).toLocaleString('ru-RU') }}</time></div><small v-if="event.actor_user_id">Инициатор · {{ event.actor_user_id }}</small><small v-if="event.target_user_id">Объект · {{ event.target_user_id }}</small></li>
    </ol>
    <button v-if="cursor" class="admin-more" type="button" :disabled="loading" @click="load(cursor)">Показать более ранние</button>
    <p v-if="error" class="admin-error" role="alert">{{ error }}</p>
  </section>
</template>
