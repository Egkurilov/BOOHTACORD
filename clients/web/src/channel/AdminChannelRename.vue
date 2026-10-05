<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { createChannelRenameEditor } from './channel_rename_editor'
import Comparison from './conflict_review/Comparison.vue'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number; channelId?: string }>()
const emit = defineEmits<{ changed: [] }>()
const localChannelId = ref('')
const selectedChannelId = computed({ get: () => props.channelId ?? localChannelId.value, set: (id: string) => { localChannelId.value = id } })
const selected = computed(() => props.categories.flatMap(({ channels }) => channels).find(({ id }) => id === selectedChannelId.value))
const editor = createChannelRenameEditor(() => ({ categories: props.categories, revision: props.revision, selectedChannelId: selectedChannelId.value }), () => emit('changed'))

watch(() => props.categories, (categories) => {
  if (props.channelId !== undefined) return
  if (!categories.some(({ channels }) => channels.some(({ id }) => id === selectedChannelId.value))) {
    selectedChannelId.value = categories.flatMap(({ channels }) => channels)[0]?.id ?? ''
  }
}, { immediate: true })
watch(() => [props.categories, props.revision, selectedChannelId.value], editor.sync, { immediate: true })

function changeDraft(event: Event): void { editor.setDraft((event.target as HTMLInputElement).value) }
</script>

<template>
  <form class="admin-topology-form admin-topology-form--rename" @submit.prevent="editor.rename">
    <label v-if="props.channelId === undefined">Канал
      <select v-model="selectedChannelId" :disabled="editor.pending.value || editor.needsRefresh.value || !selected" name="rename-channel">
        <optgroup v-for="category in categories" :key="category.id" :label="category.name">
          <option v-for="channel in category.channels" :key="channel.id" :value="channel.id">{{ channel.name }}</option>
        </optgroup>
      </select>
    </label>
    <label>Новое имя канала
      <input :value="editor.draft.value" :disabled="editor.pending.value || editor.needsRefresh.value || !selected" name="channel-new-name" required :aria-describedby="editor.error.value ? 'channel-rename-error' : undefined" @input="changeDraft">
    </label>
    <button type="submit" :disabled="editor.pending.value || editor.needsRefresh.value || editor.conflict.value || !selected">{{ editor.pending.value ? 'Сохраняем…' : 'Переименовать канал' }}</button>
    <Comparison v-if="editor.conflict.value" :before="editor.review.before.value ?? ''" :current="editor.review.current.value" :proposed="editor.draft.value" :ready="editor.review.ready(revision)" :busy="editor.pending.value" @apply="editor.applyReviewed" @discard="editor.discard" @refresh="emit('changed')" />
    <p v-if="selected" class="admin-topology-kind">Тип: {{ selected.kind === 'VOICE' ? 'голосовой' : 'текстовый' }}. Переименование не меняет тип и подключение.</p>
    <button v-if="editor.needsRefresh.value" type="button" @click="emit('changed')">Повторить обновление списка</button>
    <p v-if="editor.status.value" class="admin-topology-status" aria-live="polite">{{ editor.status.value }}</p>
    <p v-if="editor.error.value" id="channel-rename-error" class="admin-topology-error" role="alert">{{ editor.error.value }}</p>
  </form>
</template>
