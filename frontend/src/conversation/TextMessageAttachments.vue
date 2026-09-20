<script setup lang="ts">
import { ref } from 'vue'

import type { TextMessageAttachment } from './message_client'
import { textMessageAttachmentDownloadUrl } from './text_message_attachment_url'
import { textMessageAttachmentPreviewUrl } from './text_message_attachment_preview_url'

const props = defineProps<{ channelId: string; attachments: TextMessageAttachment[] }>()
const numberFormat = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 })
const failedPreviews = ref(new Set<string>())

function byteLabel(sizeBytes: number): string {
  if (sizeBytes < 1_000) return `${numberFormat.format(sizeBytes)} Б`
  if (sizeBytes < 1_000_000) return `${numberFormat.format(sizeBytes / 1_000)} КБ`
  return `${numberFormat.format(sizeBytes / 1_000_000)} МБ`
}

function isRasterName(name: string): boolean { return /\.(png|jpe?g|gif)$/i.test(name) }

function hidePreview(attachmentId: string): void {
  failedPreviews.value = new Set([...failedPreviews.value, attachmentId])
}
</script>

<template>
  <ul v-if="props.attachments.length" class="text-message-attachments" aria-label="Вложения сообщения">
    <li v-for="attachment in props.attachments" :key="attachment.id">
      <img
        v-if="isRasterName(attachment.originalName) && !failedPreviews.has(attachment.id)"
        class="attachment-preview"
        :src="textMessageAttachmentPreviewUrl(props.channelId, attachment.id)"
        :alt="`Предпросмотр: ${attachment.originalName}`"
        @error="hidePreview(attachment.id)"
      >
      <a :href="textMessageAttachmentDownloadUrl(props.channelId, attachment.id)" download>
        Скачать {{ attachment.originalName }} · {{ byteLabel(attachment.sizeBytes) }}
      </a>
    </li>
  </ul>
</template>
