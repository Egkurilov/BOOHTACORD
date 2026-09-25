<script setup lang="ts">
import { ref, watch } from 'vue'

import { uploadTextAttachment, type TextAttachmentUpload } from './text_attachment_upload_client'

const props = defineProps<{ channelId: string; disabled: boolean; clearToken: number }>()
const emit = defineEmits<{ change: [attachments: TextAttachmentUpload[]]; pending: [value: boolean] }>()
const attachments = ref<TextAttachmentUpload[]>([])
const pending = ref(false)
const error = ref<string | null>(null)
let generation = 0
const numberFormat = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 })

function byteLabel(sizeBytes: number): string {
  if (sizeBytes < 1_000) return `${numberFormat.format(sizeBytes)} Б`
  if (sizeBytes < 1_000_000) return `${numberFormat.format(sizeBytes / 1_000)} КБ`
  return `${numberFormat.format(sizeBytes / 1_000_000)} МБ`
}

function clear(): void {
  generation++
  attachments.value = []
  error.value = null
  pending.value = false
  emit('change', [])
  emit('pending', false)
}

async function addFiles(event: Event): Promise<void> {
  const input = event.currentTarget as HTMLInputElement
  const files = Array.from(input.files ?? [])
  input.value = ''
  if (!files.length || props.disabled) return
  error.value = null
  if (attachments.value.length + files.length > 10) {
    error.value = 'К сообщению можно прикрепить не более 10 файлов.'
    return
  }

  const targetChannelId = props.channelId
  const version = generation
  pending.value = true
  emit('pending', true)
  try {
    for (const file of files) {
      const uploaded = await uploadTextAttachment(targetChannelId, file)
      if (version !== generation || props.channelId !== targetChannelId) {
        return
      }
      attachments.value = [...attachments.value, uploaded]
      emit('change', [...attachments.value])
    }
  } catch (cause) {
    if (version === generation && props.channelId === targetChannelId) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить вложение.'
  } finally {
    if (version === generation && props.channelId === targetChannelId) { pending.value = false; emit('pending', false) }
  }
}

watch(() => props.clearToken, clear)
watch(() => props.channelId, clear)
</script>

<template>
  <section class="attachment-picker" aria-labelledby="message-attachments-label">
    <input id="message-attachments" class="attachment-input" type="file" multiple :disabled="props.disabled || pending" @change="addFiles">
    <label id="message-attachments-label" class="attachment-trigger" for="message-attachments" aria-label="Прикрепить файлы">+</label>
    <p class="attachment-hint">До 10 файлов по 25 МБ. Файлы будут прикреплены после отправки текста.</p>
    <p v-if="pending" class="attachment-state" aria-live="polite">Загружаем вложение…</p>
    <p v-if="error" class="attachment-state attachment-error" role="alert">{{ error }}</p>
    <ul v-if="attachments.length" class="attachment-list" aria-label="Подготовленные вложения">
      <li v-for="attachment in attachments" :key="attachment.id">{{ attachment.originalName }} · {{ byteLabel(attachment.sizeBytes) }}</li>
    </ul>
  </section>
</template>
