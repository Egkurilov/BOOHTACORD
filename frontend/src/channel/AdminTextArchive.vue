<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { useVoiceNavigationStore } from '../voice/navigation_store'
import { createTextArchiveEditor } from './text_archive_editor'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number }>()
const emit = defineEmits<{ changed: [] }>()
const navigation = useVoiceNavigationStore()
const selectedChannelId = ref('')
const textChannels = computed(() => props.categories.flatMap(({ channels }) => channels).filter(({ kind }) => kind === 'TEXT'))
const editor = createTextArchiveEditor(() => ({ categories: props.categories, revision: props.revision, selectedChannelId: selectedChannelId.value }),
  () => emit('changed'), (id) => navigation.clearSelectedText(id), (message) => window.confirm(message))

watch(textChannels, (channels) => {
  if (!channels.some(({ id }) => id === selectedChannelId.value)) selectedChannelId.value = channels[0]?.id ?? ''
}, { immediate: true })
watch(() => [props.categories, props.revision, selectedChannelId.value], editor.sync, { immediate: true })
</script>

<template>
  <form class="admin-topology-form admin-topology-form--rename" @submit.prevent="editor.archive">
    <label>Текстовый канал для архивации
      <select v-model="selectedChannelId" :disabled="editor.pending.value || editor.needsRefresh.value || !textChannels.length" name="archive-text-channel">
        <option v-for="channel in textChannels" :key="channel.id" :value="channel.id">{{ channel.name }}</option>
      </select>
    </label>
    <p class="admin-topology-kind">После архивации канал исчезнет из навигации. История сообщений сохранится.</p>
    <button type="submit" :disabled="editor.pending.value || editor.needsRefresh.value || !selectedChannelId">{{ editor.pending.value ? 'Архивируем…' : 'Архивировать канал' }}</button>
    <button v-if="editor.needsRefresh.value" type="button" @click="emit('changed')">Повторить обновление списка</button>
    <p v-if="editor.status.value" class="admin-topology-status" aria-live="polite">{{ editor.status.value }}</p>
    <p v-if="editor.error.value" class="admin-topology-error" role="alert">{{ editor.error.value }}</p>
  </form>
</template>
