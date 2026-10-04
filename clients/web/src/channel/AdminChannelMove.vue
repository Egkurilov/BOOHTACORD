<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { createChannelMoveEditor } from './channel_move_editor'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number; channelId?: string }>()
const emit = defineEmits<{ changed: [] }>()
const localChannelId = ref('')
const selectedChannelId = computed({ get: () => props.channelId ?? localChannelId.value, set: (id: string) => { localChannelId.value = id } })
const selected = computed(() => props.categories.flatMap(({ channels }) => channels).find(({ id }) => id === selectedChannelId.value))
const editor = createChannelMoveEditor(() => ({ categories: props.categories, revision: props.revision, selectedChannelId: selectedChannelId.value }), () => emit('changed'))

watch(() => props.categories, (categories) => {
  if (props.channelId !== undefined) return
  if (!categories.some(({ channels }) => channels.some(({ id }) => id === selectedChannelId.value))) {
    selectedChannelId.value = categories.flatMap(({ channels }) => channels)[0]?.id ?? ''
  }
}, { immediate: true })
watch(() => [props.categories, props.revision, selectedChannelId.value], editor.sync, { immediate: true })
function changeTarget(event: Event): void { editor.setTargetCategoryId((event.target as HTMLSelectElement).value) }
</script>

<template>
  <form class="admin-topology-form admin-topology-form--rename" @submit.prevent="editor.move">
    <label v-if="props.channelId === undefined">Перенести канал
      <select v-model="selectedChannelId" :disabled="editor.pending.value || editor.needsRefresh.value || !selected" name="move-channel">
        <optgroup v-for="category in categories" :key="category.id" :label="category.name">
          <option v-for="channel in category.channels" :key="channel.id" :value="channel.id">{{ channel.name }}</option>
        </optgroup>
      </select>
    </label>
    <label>В категорию
      <select :value="editor.targetCategoryId.value" :disabled="editor.pending.value || editor.needsRefresh.value || !selected" name="target-category" @change="changeTarget">
        <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.name }}</option>
      </select>
    </label>
    <button type="submit" :disabled="!editor.canMove()">{{ editor.pending.value ? 'Переносим…' : 'Перенести канал' }}</button>
    <p v-if="selected" class="admin-topology-kind">Канал останется {{ selected.kind === 'VOICE' ? 'голосовым' : 'текстовым' }}. Изменится только его категория.</p>
    <button v-if="editor.needsRefresh.value" type="button" @click="emit('changed')">Повторить обновление списка</button>
    <p v-if="editor.status.value" class="admin-topology-status" aria-live="polite">{{ editor.status.value }}</p>
    <p v-if="editor.error.value" class="admin-topology-error" role="alert">{{ editor.error.value }}</p>
  </form>
</template>
