<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { createChannelOrderEditor } from './channel_order_editor'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number }>()
const emit = defineEmits<{ changed: [] }>()
const selectedCategoryId = ref('')
const selectedChannelId = ref('')
const category = computed(() => props.categories.find(({ id }) => id === selectedCategoryId.value))
const channels = computed(() => [...(category.value?.channels ?? [])].sort((a, b) => a.position - b.position || a.id.localeCompare(b.id)))
const selected = computed(() => channels.value.find(({ id }) => id === selectedChannelId.value))
const editor = createChannelOrderEditor(() => ({ categories: props.categories, revision: props.revision, selectedCategoryId: selectedCategoryId.value, selectedChannelId: selectedChannelId.value }), () => emit('changed'))

watch(() => props.categories, (categories) => {
  if (!categories.some(({ id }) => id === selectedCategoryId.value)) selectedCategoryId.value = categories.find(({ channels }) => channels.length)?.id ?? categories[0]?.id ?? ''
}, { immediate: true })
watch([() => props.categories, selectedCategoryId], () => {
  if (!channels.value.some(({ id }) => id === selectedChannelId.value)) selectedChannelId.value = channels.value[0]?.id ?? ''
}, { immediate: true })
watch(() => [props.categories, props.revision, selectedCategoryId.value], editor.sync, { immediate: true })
</script>

<template>
  <div class="admin-channel-order admin-topology-form admin-topology-form--rename">
    <label>Порядок в категории
      <select v-model="selectedCategoryId" :disabled="editor.pending.value || editor.needsRefresh.value || !categories.length" name="order-category">
        <option v-for="item in categories" :key="item.id" :value="item.id">{{ item.name }}</option>
      </select>
    </label>
    <label>Канал
      <select v-model="selectedChannelId" :disabled="editor.pending.value || editor.needsRefresh.value || !channels.length" name="order-channel">
        <option v-for="item in channels" :key="item.id" :value="item.id">{{ item.name }}</option>
      </select>
    </label>
    <div class="admin-category-order" role="group" aria-label="Порядок каналов">
      <button type="button" :disabled="!editor.canMove(-1)" :aria-label="`Переместить канал «${selected?.name ?? ''}» выше`" @click="editor.move(-1)">Выше</button>
      <button type="button" :disabled="!editor.canMove(1)" :aria-label="`Переместить канал «${selected?.name ?? ''}» ниже`" @click="editor.move(1)">Ниже</button>
    </div>
    <p class="admin-topology-kind">Порядок изменится после ответа сервера и обновления списка.</p>
    <button v-if="editor.needsRefresh.value" type="button" @click="emit('changed')">Повторить обновление списка</button>
    <p v-if="editor.status.value" class="admin-topology-status" aria-live="polite">{{ editor.status.value }}</p>
    <p v-if="editor.error.value" class="admin-topology-error" role="alert">{{ editor.error.value }}</p>
  </div>
</template>
