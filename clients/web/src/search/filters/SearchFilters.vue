<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useMemberDirectory } from '../../identity/member_directory'
import type { AttachmentFilter } from './state'

const props = defineProps<{
  authorId: string
  attachment: AttachmentFilter
  dateFrom: string
  dateTo: string
  disabled?: boolean
}>()
const emit = defineEmits<{
  'update:authorId': [value: string]
  'update:attachment': [value: AttachmentFilter]
  'update:dateFrom': [value: string]
  'update:dateTo': [value: string]
}>()
const members = useMemberDirectory()
const authorOptions = computed(() =>
  [...members.members].sort((left, right) =>
    left.display_name.localeCompare(right.display_name, 'ru'),
  ),
)

onMounted(() => {
  if (!members.members.length && !members.loading) void members.refresh()
})
</script>

<template>
  <fieldset class="search-filters" :disabled="disabled">
    <legend>Фильтры</legend>
    <label>
      <span>Автор</span>
      <select :value="authorId" @change="emit('update:authorId', ($event.target as HTMLSelectElement).value)">
        <option value="">Любой автор</option>
        <option v-for="member in authorOptions" :key="member.user_id" :value="member.user_id">
          {{ member.display_name }} ({{ member.login }})
        </option>
      </select>
    </label>
    <p v-if="members.error" class="search-filter-error" role="alert">
      Не удалось загрузить список авторов.
    </p>
    <button v-if="members.cursor" type="button" :disabled="members.loading" @click="members.loadNext()">
      {{ members.loading ? 'Загружаем…' : 'Загрузить ещё участников' }}
    </button>
    <label>
      <span>Вложения</span>
      <select :value="attachment" @change="emit('update:attachment', ($event.target as HTMLSelectElement).value as AttachmentFilter)">
        <option value="any">Любые</option>
        <option value="with">С вложениями</option>
        <option value="without">Без вложений</option>
      </select>
    </label>
    <label><span>С даты</span><input type="date" :value="dateFrom" :max="dateTo || undefined" @input="emit('update:dateFrom', ($event.target as HTMLInputElement).value)"></label>
    <label><span>По дату включительно</span><input type="date" :value="dateTo" :min="dateFrom || undefined" @input="emit('update:dateTo', ($event.target as HTMLInputElement).value)"></label>
    <small>Даты в вашем часовом поясе.</small>
  </fieldset>
</template>

<style scoped>
.search-filters { display: flex; flex-wrap: wrap; min-width: 0; align-items: end; gap: 8px 12px; border: 0; margin: 0; padding: 0; }
.search-filters legend { font-size: 0.85rem; font-weight: 600; margin-bottom: 6px; }
.search-filters label { display: grid; gap: 4px; }
.search-filters input, .search-filters select, .search-filters button { min-height: 36px; }
.search-filter-error { margin: 0; }
.search-filters small { flex-basis: 100%; }
</style>
