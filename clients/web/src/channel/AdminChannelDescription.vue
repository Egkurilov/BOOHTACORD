<script setup lang="ts">
import { ref, watch } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'
import { ChannelDescriptionError, updateChannelDescription } from './channel_description_client'

const props = defineProps<{ channelId: string; description?: string; revision: number }>()
const emit = defineEmits<{ changed: [] }>()
const draft = ref('')
const pending = ref(false)
const error = ref<string | null>(null)
const status = ref<string | null>(null)
let lastSaved: string | null = null

watch(() => props.channelId, () => {
  draft.value = props.description ?? ''
  error.value = null
  status.value = null
  lastSaved = null
}, { immediate: true })
watch(() => props.description, (description) => {
  draft.value = description ?? ''
  error.value = null
  if (description !== lastSaved) status.value = null
})

async function save(): Promise<void> {
  if (pending.value || props.revision < 1) return
  error.value = null
  status.value = null
  if (!validCodePointLength(draft.value, 0, 200)) {
    error.value = 'Описание канала не должно превышать 200 символов.'
    return
  }
  pending.value = true
  try {
    await updateChannelDescription(props.channelId, draft.value, props.revision)
    lastSaved = draft.value
    status.value = 'Описание сохранено.'
    emit('changed')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'Не удалось сохранить описание канала.'
    if (cause instanceof ChannelDescriptionError && cause.status === 409) emit('changed')
  } finally { pending.value = false }
}
</script>

<template>
  <form class="admin-topology-form admin-topology-form--description" @submit.prevent="save">
    <label>Описание канала
      <textarea v-model="draft" name="channel-description" maxlength="200" rows="2" :disabled="pending || revision < 1" :aria-describedby="error ? 'channel-description-error' : undefined" />
    </label>
    <button type="submit" :disabled="pending || revision < 1">{{ pending ? 'Сохраняем…' : 'Сохранить описание' }}</button>
    <p v-if="status" class="admin-topology-status" aria-live="polite">{{ status }}</p>
    <p v-if="error" id="channel-description-error" class="admin-topology-error" role="alert">{{ error }}</p>
  </form>
</template>
