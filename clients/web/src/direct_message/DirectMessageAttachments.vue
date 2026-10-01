<script setup lang="ts">
import type { TextMessageAttachment } from '../conversation/message_client'
import PublishedAttachmentCard from '../conversation/PublishedAttachmentCard.vue'
import { directMessageAttachmentDownloadUrl, directMessageAttachmentPreviewUrl } from './direct_message_attachment_url'

const props = defineProps<{ directMessageId: string; attachments: TextMessageAttachment[] }>()
</script>

<template>
  <ul v-if="props.attachments.length" class="text-message-attachments" aria-label="Вложения личного сообщения">
    <PublishedAttachmentCard
      v-for="attachment in props.attachments"
      :key="attachment.id"
      :attachment="attachment"
      :download-url="directMessageAttachmentDownloadUrl(props.directMessageId, attachment.id)"
      :preview-url="directMessageAttachmentPreviewUrl(props.directMessageId, attachment.id)"
    />
  </ul>
</template>
