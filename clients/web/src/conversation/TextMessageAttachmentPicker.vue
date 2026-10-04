<script setup lang="ts">
import { ref, watch } from 'vue'

import type { TextAttachmentUpload } from './text_attachment_upload_client'
import { useTextAttachmentQueue } from './text_attachment_queue'
import { useCompactComposerActions } from './use_compact_composer_actions'

const props = defineProps<{ channelId: string; disabled: boolean; clearToken: number; initialAttachments?: TextAttachmentUpload[] }>()
const emit = defineEmits<{ change: [attachments: TextAttachmentUpload[]]; pending: [value: boolean]; mention: []; emoji: [] }>()
const fileInput = ref<HTMLInputElement | null>(null)
const { compact, menuOpen, trigger, firstAction, toggle, close, onFocusOut } = useCompactComposerActions()
function openActions(): void { if (compact.value) toggle(); else fileInput.value?.click() }
function chooseFile(): void { close(); fileInput.value?.click() }
function chooseMention(): void { close(); emit('mention') }
function chooseEmoji(): void { close(); emit('emoji') }
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
    <button id="message-attachments-label" ref="trigger" class="attachment-trigger" type="button" :aria-label="compact ? 'Действия редактора' : 'Прикрепить файлы'" :aria-expanded="compact ? menuOpen : undefined" :disabled="props.disabled || pending" @click="openActions"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg></button>
    <div v-if="menuOpen" class="composer-mobile-actions" role="group" aria-label="Действия редактора" @keydown.esc.stop.prevent="close(true)" @focusout="onFocusOut">
      <button ref="firstAction" type="button" @click="chooseFile">Прикрепить файл</button>
      <button type="button" @click="chooseMention">Упомянуть</button>
      <button type="button" @click="chooseEmoji">Emoji</button>
    </div>
    <p class="attachment-hint">До 10 файлов по 25 МБ. Файлы будут прикреплены после отправки сообщения.</p>
    <p v-if="pending" class="attachment-state" aria-live="polite">Загружаем вложение…</p>
    <p v-if="error" class="attachment-state attachment-error" role="alert">{{ error }}</p>
    <button v-if="failed.length" type="button" :disabled="pending || props.disabled" @click="retry">Повторить загрузку ({{ failed.length }})</button>
    <ul v-if="attachments.length" class="attachment-list" aria-label="Подготовленные вложения">
      <li v-for="attachment in attachments" :key="attachment.id">{{ attachment.originalName }} · {{ byteLabel(attachment.sizeBytes) }}</li>
    </ul>
  </section>
</template>
