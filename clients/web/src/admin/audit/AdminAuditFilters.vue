<script setup lang="ts">
import { computed } from 'vue'
import type { AuditEvent } from '../../identity/admin_directory_client'
import { presentAuditEvent } from './audit_event_display'
import type { AuditFilters } from './audit_filter'

const props = defineProps<{ events: AuditEvent[]; filters: AuditFilters }>()
const emit = defineEmits<{ 'update:filters': [filters: AuditFilters] }>()
const hasFilters = computed(() => props.filters.scope !== 'all' || Boolean(props.filters.from || props.filters.to || props.filters.type || props.filters.actor))
const types = computed(() => [...new Map(props.events.map((event) => [event.event_type, presentAuditEvent(event).title])).entries()]
  .sort((a, b) => a[1].localeCompare(b[1], 'ru')))
const actors = computed(() => [...new Map(props.events.map((event) => [event.actor_user_id ?? 'system', presentAuditEvent(event).actor])).entries()]
  .sort((a, b) => a[1].localeCompare(b[1], 'ru')))
function change(key: keyof AuditFilters, event: Event): void {
  emit('update:filters', { ...props.filters, [key]: (event.target as HTMLInputElement).value })
}
function reset(): void { emit('update:filters', { scope: 'all' }) }
</script>

<template>
  <div class="admin-audit-filters" role="group" aria-label="Фильтры журнала аудита">
    <label>Область<select :value="filters.scope" @change="change('scope', $event)">
      <option value="all">Все</option><option value="admin">Администрирование</option><option value="voice">Голос</option>
    </select></label>
    <label>С даты<input type="date" :value="filters.from ?? ''" @change="change('from', $event)"></label>
    <label>По дату<input type="date" :value="filters.to ?? ''" @change="change('to', $event)"></label>
    <label>Действие<select :value="filters.type ?? ''" @change="change('type', $event)">
      <option value="">Все действия</option><option v-for="[type, title] in types" :key="type" :value="type">{{ title }}</option>
    </select></label>
    <label>Инициатор<select :value="filters.actor ?? ''" @change="change('actor', $event)">
      <option value="">Все инициаторы</option><option v-for="[id, title] in actors" :key="id" :value="id">{{ title }}</option>
    </select></label>
    <button v-if="hasFilters" type="button" @click="reset">Сбросить фильтры</button>
  </div>
</template>
