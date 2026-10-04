<script setup lang="ts">
import { ref, watch } from 'vue'

import type { TextAttachmentUpload } from './text_attachment_upload_client'
import { useTextAttachmentQueue } from './text_attachment_queue'

const props = defineProps<{ channelId: string; disabled: boolean; clearToken: number; initialAttachments?: TextAttachmentUpload[] }>()
const emit = defineEmits<{ change: [attachments: TextAttachmentUpload[]]; pending: [value: boolean] }>()
const fileInput = ref<HTMLInputElement | null>(null)
const { attachments, failed, pending, error, clear, restore, upload, addFiles, retry } = useTextAttachmentQueue(
  () => props.channelId, () => props.disabled, emit, undefined, props.initialAttachments,
)
const numberFormat = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 })

function byteLabel(sizeBytes: number): string {
  if (sizeBytes < 1_000) return `${numberFormat.format(sizeBytes)} Б`
  if (sizeBytes < 1_000_000) return `${numberFormat.format(sizeBytes / 1_000)} КБ`
  return `${numberFormat.format(sizeBytes / 1_000_000)} МБ`
}

watch(() => props.clearToken, clear)
watch(() => props.channelId, () => restore(props.initialAttachments ?? []))

function addPastedFiles(files: File[]): void { void upload(files) }
defineExpose({ addPastedFiles })
</script>

<template>
  <section class="attachment-picker" aria-labelledby="message-attachments-label">
    <input ref="fileInput" id="message-attachments" class="attachment-input" type="file" multiple tabindex="-1" aria-hidden="true" :disabled="props.disabled || pending" @change="addFiles">
    <button id="message-attachments-label" class="attachment-trigger" type="button" aria-label="Прикрепить файлы" :disabled="props.disabled || pending" @click="fileInput?.click()"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg></button>
    <p class="attachment-hint">До 10 файлов по 25 МБ. Файлы будут прикреплены после отправки сообщения.</p>
    <p v-if="pending" class="attachment-state" aria-live="polite">Загружаем вложение…</p>
    <p v-if="error" class="attachment-state attachment-error" role="alert">{{ error }}</p>
    <button v-if="failed.length" type="button" :disabled="pending || props.disabled" @click="retry">Повторить загрузку ({{ failed.length }})</button>
    <ul v-if="attachments.length" class="attachment-list" aria-label="Подготовленные вложения">
      <li v-for="attachment in attachments" :key="attachment.id">{{ attachment.originalName }} · {{ byteLabel(attachment.sizeBytes) }}</li>
    </ul>
  </section>
</template>
