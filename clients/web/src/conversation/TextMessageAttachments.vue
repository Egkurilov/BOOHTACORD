<script setup lang="ts">
import type { TextMessageAttachment } from './message_client'
import PublishedAttachmentCard from './attachment_card/PublishedAttachmentCard.vue'
import { textMessageAttachmentDownloadUrl } from './text_message_attachment_url'
import { textMessageAttachmentPreviewUrl } from './text_message_attachment_preview_url'

const props = defineProps<{ channelId: string; attachments: TextMessageAttachment[] }>()
</script>

<template>
  <ul v-if="props.attachments.length" class="text-message-attachments" aria-label="Вложения сообщения">
    <PublishedAttachmentCard
      v-for="attachment in props.attachments"
      :key="attachment.id"
      :attachment="attachment"
      :download-url="textMessageAttachmentDownloadUrl(props.channelId, attachment.id)"
      :preview-url="textMessageAttachmentPreviewUrl(props.channelId, attachment.id)"
    />
  </ul>
</template>
