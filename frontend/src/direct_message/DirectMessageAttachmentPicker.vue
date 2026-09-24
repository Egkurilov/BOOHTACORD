<script setup lang="ts">
import { ref, watch } from 'vue'
import type { TextMessageAttachment } from '../conversation/message_client'
import { uploadDirectMessageAttachment } from './direct_message_attachment_upload_client'

const props = defineProps<{ directMessageId: string; disabled: boolean; clearToken: number }>()
const emit = defineEmits<{ change: [attachments: TextMessageAttachment[]]; pending: [value: boolean] }>()
const attachments = ref<TextMessageAttachment[]>([])
const failed = ref<File[]>([])
const pending = ref(false)
const error = ref<string | null>(null)
let generation = 0
const format = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 })
function byteLabel(size: number): string { return size < 1_000 ? `${format.format(size)} Б` : size < 1_000_000 ? `${format.format(size / 1_000)} КБ` : `${format.format(size / 1_000_000)} МБ` }

function clear(): void {
  generation++
  attachments.value = []
  failed.value = []
  error.value = null
  pending.value = false
  emit('change', [])
  emit('pending', false)
}

async function upload(files: File[]): Promise<void> {
  if (!files.length || pending.value || props.disabled) return
  if (attachments.value.length + failed.value.length + files.length > 10) { error.value = 'К сообщению можно прикрепить не более 10 файлов.'; return }
  const target = props.directMessageId
  const version = generation
  pending.value = true
  error.value = null
  emit('pending', true)
  try {
    for (const file of files) {
      try {
        const result = await uploadDirectMessageAttachment(target, file)
        if (version !== generation || target !== props.directMessageId) return
        attachments.value = [...attachments.value, result]
        emit('change', [...attachments.value])
      } catch (cause) {
        if (version !== generation || target !== props.directMessageId) return
        failed.value = [...failed.value, file]
        error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить вложение.'
      }
    }
  } finally {
    if (version === generation && target === props.directMessageId) { pending.value = false; emit('pending', false) }
  }
}

function addFiles(event: Event): void {
  const input = event.currentTarget as HTMLInputElement
  const files = Array.from(input.files ?? [])
  input.value = ''
  void upload(files)
}

function retry(): void {
  const files = failed.value
  failed.value = []
  void upload(files)
}

watch(() => props.clearToken, clear)
watch(() => props.directMessageId, clear)
</script>

<template>
  <section class="attachment-picker" aria-labelledby="dm-attachments-label">
    <input id="dm-attachments" class="attachment-input" type="file" multiple :disabled="props.disabled || pending" @change="addFiles">
    <label id="dm-attachments-label" class="attachment-trigger" for="dm-attachments" aria-label="Прикрепить файлы">+</label>
    <p class="attachment-hint">До 10 файлов по 25 МБ. Файлы прикрепятся после отправки сообщения.</p>
    <p v-if="pending" class="attachment-state" aria-live="polite">Загружаем вложение…</p>
    <p v-if="error" class="attachment-state attachment-error" role="alert">{{ error }}</p>
    <button v-if="failed.length" type="button" :disabled="pending || props.disabled" @click="retry">Повторить загрузку ({{ failed.length }})</button>
    <ul v-if="attachments.length" class="attachment-list" aria-label="Подготовленные вложения">
      <li v-for="attachment in attachments" :key="attachment.id">{{ attachment.originalName }} · {{ byteLabel(attachment.sizeBytes) }}</li>
    </ul>
  </section>
</template>
