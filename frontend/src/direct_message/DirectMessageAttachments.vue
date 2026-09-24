<script setup lang="ts">
import { ref } from 'vue'
import type { TextMessageAttachment } from '../conversation/message_client'
import { directMessageAttachmentDownloadUrl, directMessageAttachmentPreviewUrl } from './direct_message_attachment_url'

const props = defineProps<{ directMessageId: string; attachments: TextMessageAttachment[] }>()
const failedPreviews = ref(new Set<string>())
const numberFormat = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 })
function byteLabel(size: number): string {
  if (size < 1_000) return `${numberFormat.format(size)} Б`
  if (size < 1_000_000) return `${numberFormat.format(size / 1_000)} КБ`
  return `${numberFormat.format(size / 1_000_000)} МБ`
}
function hidePreview(id: string): void { failedPreviews.value = new Set([...failedPreviews.value, id]) }
</script>

<template>
  <ul v-if="props.attachments.length" class="text-message-attachments" aria-label="Вложения личного сообщения">
    <li v-for="attachment in props.attachments" :key="attachment.id">
      <img v-if="/\.(png|jpe?g|gif)$/i.test(attachment.originalName) && !failedPreviews.has(attachment.id)"
        class="attachment-preview" :src="directMessageAttachmentPreviewUrl(props.directMessageId, attachment.id)"
        :alt="`Предпросмотр: ${attachment.originalName}`" @error="hidePreview(attachment.id)">
      <a :href="directMessageAttachmentDownloadUrl(props.directMessageId, attachment.id)" download>Скачать {{ attachment.originalName }} · {{ byteLabel(attachment.sizeBytes) }}</a>
    </li>
  </ul>
</template>
