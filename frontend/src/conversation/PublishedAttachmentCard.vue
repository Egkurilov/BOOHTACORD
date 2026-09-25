<script setup lang="ts">
import { computed, ref } from 'vue'

import type { TextMessageAttachment } from './message_client'

const props = defineProps<{
  attachment: TextMessageAttachment
  downloadUrl: string
  previewUrl: string
}>()

const failedPreview = ref(false)
const showPreview = computed(() => /\.(png|jpe?g|gif)$/i.test(props.attachment.originalName) && !failedPreview.value)
const numberFormat = new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 })

function byteLabel(sizeBytes: number): string {
  if (sizeBytes < 1_000) return `${numberFormat.format(sizeBytes)} Б`
  if (sizeBytes < 1_000_000) return `${numberFormat.format(sizeBytes / 1_000)} КБ`
  return `${numberFormat.format(sizeBytes / 1_000_000)} МБ`
}
</script>

<template>
  <li class="attachment-card-item">
    <a
      class="attachment-card"
      :href="props.downloadUrl"
      :aria-label="`Скачать ${props.attachment.originalName}, ${byteLabel(props.attachment.sizeBytes)}`"
      download
    >
      <img
        v-if="showPreview"
        class="attachment-card__preview"
        :src="props.previewUrl"
        alt=""
        @error="failedPreview = true"
      >
      <svg v-else class="attachment-card__file-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="M7 3h7l4 4v14H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Z" />
        <path d="M14 3v5h5M9 13h6M9 17h6" />
      </svg>
      <span class="attachment-card__details">
        <span class="attachment-card__name">{{ props.attachment.originalName }}</span>
        <span class="attachment-card__size">{{ byteLabel(props.attachment.sizeBytes) }}</span>
      </span>
      <svg class="attachment-card__download-icon" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="M12 3v12m-4-4 4 4 4-4M5 17v3h14v-3" />
      </svg>
    </a>
  </li>
</template>
