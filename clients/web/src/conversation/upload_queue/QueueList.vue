<script setup lang="ts">
import type { Item, Prepared } from './types'
defineProps<{ items: Item<Prepared>[]; disabled: boolean }>()
const emit = defineEmits<{ retry: [key: number]; cancel: [key: number] }>()
const size = (bytes: number) => `${(bytes / 1_000_000).toLocaleString('ru-RU', { maximumFractionDigits: 1 })} МБ`
</script>

<template>
  <ul v-if="items.length" class="attachment-list upload-queue" aria-label="Очередь вложений">
    <li v-for="item in items" :key="item.key" :data-upload-key="item.key" :data-upload-status="item.status">
      <span>{{ item.name }} · {{ size(item.sizeBytes) }}</span>
      <progress v-if="item.status === 'uploading'" :value="item.progress" max="100" :aria-label="`Загрузка ${item.name}`" />
      <span v-if="item.status === 'uploading'">{{ item.progress }}%</span>
      <span v-if="item.status === 'queued'">В очереди</span>
      <span v-if="item.status === 'done'">Готово</span>
      <span v-if="item.error" role="alert">{{ item.error }}</span>
      <button v-if="item.status === 'failed'" type="button" :disabled="disabled" :aria-label="`Повторить загрузку ${item.name}`" @click="emit('retry', item.key)">Повторить</button>
      <button type="button" :disabled="disabled" :aria-label="`${item.status === 'uploading' ? 'Отменить загрузку' : 'Убрать'} ${item.name}`" @click="emit('cancel', item.key)">{{ item.status === 'uploading' ? 'Отменить' : 'Убрать' }}</button>
    </li>
  </ul>
</template>

<style scoped>
.upload-queue li { display: flex; flex-wrap: wrap; align-items: center; gap: var(--space-2, 8px); }
.upload-queue progress { max-width: 120px; }
</style>
