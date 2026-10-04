<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'

import AdminConfirmation from './AdminConfirmation.vue'
import { createVoiceCloseEditor } from './voice_close_editor'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number; channelId?: string }>()
const emit = defineEmits<{ changed: [] }>()
const localChannelId = ref('')
const selectedChannelId = computed({ get: () => props.channelId ?? localChannelId.value, set: (id: string) => { localChannelId.value = id } })
const confirmation = ref<{ ask: (message: string) => Promise<boolean> } | null>(null)
const statusNode = ref<HTMLElement | null>(null)
const errorNode = ref<HTMLElement | null>(null)
const voiceChannels = computed(() => props.categories.flatMap(({ channels }) => channels).filter(({ kind }) => kind === 'VOICE'))
const selected = computed(() => voiceChannels.value.find(({ id }) => id === selectedChannelId.value))
const editor = createVoiceCloseEditor(() => ({ categories: props.categories, revision: props.revision, selectedChannelId: selectedChannelId.value }),
  () => emit('changed'), (message) => confirmation.value?.ask(message) ?? false)

watch(voiceChannels, (channels) => {
  if (props.channelId !== undefined) return
  if (!channels.some(({ id }) => id === selectedChannelId.value)) selectedChannelId.value = channels[0]?.id ?? ''
}, { immediate: true })
watch(() => [props.categories, props.revision, selectedChannelId.value], editor.sync, { immediate: true })
watch(editor.status, async (message) => { if (message) { await nextTick(); statusNode.value?.focus() } })
watch(editor.error, async (message) => { if (message) { await nextTick(); errorNode.value?.focus() } })
</script>

<template>
  <form class="admin-topology-form admin-topology-form--rename" @submit.prevent="editor.close">
    <label v-if="props.channelId === undefined">Голосовой канал для закрытия
      <select v-model="selectedChannelId" :disabled="editor.pending.value || editor.needsRefresh.value || !voiceChannels.length" name="close-voice-channel">
        <option v-for="channel in voiceChannels" :key="channel.id" :value="channel.id">{{ channel.name }}{{ channel.admissionClosed ? ' · вход закрыт' : '' }}</option>
      </select>
    </label>
    <p class="admin-topology-kind">Сначала закрывается вход. Отзыв media-доступа в SFU и окончательное удаление подтвердит сервер; число отозванных leases не подтверждает отключение участников.</p>
    <button type="submit" :disabled="editor.pending.value || editor.needsRefresh.value || !selected || selected.admissionClosed">{{ editor.pending.value ? 'Закрываем вход…' : 'Закрыть вход' }}</button>
    <button v-if="editor.needsRefresh.value || editor.phase.value === 'pending'" type="button" @click="emit('changed')">Проверить состояние</button>
    <p v-if="editor.status.value" ref="statusNode" class="admin-topology-status" role="status" tabindex="-1">{{ editor.status.value }}</p>
    <p v-if="editor.error.value" ref="errorNode" class="admin-topology-error" role="alert" tabindex="-1">{{ editor.error.value }}</p>
    <AdminConfirmation ref="confirmation" id="voice-close-confirm" title="Подтверждение закрытия" confirm-label="Закрыть вход" />
  </form>
</template>
