<script setup lang="ts">
import { computed, ref } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import { createChannel } from './admin_topology_client'
import type { ChannelKind, TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; categoryId: string }>()
const emit = defineEmits<{ changed: [] }>()
const selected = computed(() => props.categories.find(({ id }) => id === props.categoryId))
const channelName = ref('')
const channelKind = ref<ChannelKind>('VOICE')
const pending = ref(false)
const error = ref<string | null>(null)
const status = ref<string | null>(null)

async function submit(): Promise<void> {
  if (pending.value) return
  error.value = null
  status.value = null
  if (!selected.value) { error.value = 'Сначала выберите раздел.'; return }
  if (!channelName.value.trim() || !validCodePointLength(channelName.value, 1, 80)) {
    error.value = 'Введите имя канала до 80 символов.'
    return
  }
  pending.value = true
  try {
    await createChannel(selected.value.id, { name: channelName.value, kind: channelKind.value })
    channelName.value = ''
    status.value = 'Канал создан. Топология обновляется.'
    emit('changed')
  } catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось создать канал.' }
  finally { pending.value = false }
}
</script>

<template>
  <form class="admin-topology-form admin-topology-form--channel" @submit.prevent="submit">
    <h4>Добавить канал в «{{ selected?.name ?? 'раздел' }}»</h4>
    <label>Новый канал<input v-model="channelName" :disabled="pending || !selected" name="channel-name" required :aria-invalid="error ? 'true' : undefined" :aria-describedby="error ? 'admin-topology-error' : undefined"></label>
    <label>Тип канала<select v-model="channelKind" :disabled="pending || !selected" name="channel-kind">
      <option value="VOICE">Голосовой</option><option value="TEXT">Текстовый</option>
    </select></label>
    <button type="submit" :disabled="pending || !selected">Создать канал</button>
    <p v-if="status" class="admin-topology-status" aria-live="polite">{{ status }}</p>
    <p v-if="error" id="admin-topology-error" class="admin-topology-error" role="alert">{{ error }}</p>
  </form>
</template>
