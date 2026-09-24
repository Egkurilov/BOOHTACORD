<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { createVoiceCloseEditor } from './voice_close_editor'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number }>()
const emit = defineEmits<{ changed: [] }>()
const selectedChannelId = ref('')
const voiceChannels = computed(() => props.categories.flatMap(({ channels }) => channels).filter(({ kind }) => kind === 'VOICE'))
const selected = computed(() => voiceChannels.value.find(({ id }) => id === selectedChannelId.value))
const editor = createVoiceCloseEditor(() => ({ categories: props.categories, revision: props.revision, selectedChannelId: selectedChannelId.value }),
  () => emit('changed'), (message) => window.confirm(message))

watch(voiceChannels, (channels) => {
  if (!channels.some(({ id }) => id === selectedChannelId.value)) selectedChannelId.value = channels[0]?.id ?? ''
}, { immediate: true })
watch(() => [props.categories, props.revision, selectedChannelId.value], editor.sync, { immediate: true })
</script>

<template>
  <form class="admin-topology-form admin-topology-form--rename" @submit.prevent="editor.close">
    <label>Голосовой канал для закрытия
      <select v-model="selectedChannelId" :disabled="editor.pending.value || editor.needsRefresh.value || !voiceChannels.length" name="close-voice-channel">
        <option v-for="channel in voiceChannels" :key="channel.id" :value="channel.id">{{ channel.name }}{{ channel.admissionClosed ? ' · вход закрыт' : '' }}</option>
      </select>
    </label>
    <p class="admin-topology-kind">Сначала закрывается вход. Отзыв media-доступа в SFU и окончательное удаление подтвердит сервер; число отозванных leases не подтверждает отключение участников.</p>
    <button type="submit" :disabled="editor.pending.value || editor.needsRefresh.value || !selected || selected.admissionClosed">{{ editor.pending.value ? 'Закрываем вход…' : 'Закрыть вход' }}</button>
    <button v-if="editor.needsRefresh.value || editor.phase.value === 'pending'" type="button" @click="emit('changed')">Проверить состояние</button>
    <p v-if="editor.status.value" class="admin-topology-status" aria-live="polite">{{ editor.status.value }}</p>
    <p v-if="editor.error.value" class="admin-topology-error" role="alert">{{ editor.error.value }}</p>
  </form>
</template>
