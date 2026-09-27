import { ref } from 'vue'

import { uploadTextAttachment, type TextAttachmentUpload } from './text_attachment_upload_client'
import { exceedsAttachmentCount } from './attachment_limits'

type Emit = ((event: 'change', attachments: TextAttachmentUpload[]) => void) & ((event: 'pending', value: boolean) => void)
type Upload = typeof uploadTextAttachment

export function useTextAttachmentQueue(channelId: () => string, disabled: () => boolean, emit: Emit, uploadFile: Upload = uploadTextAttachment) {
  const attachments = ref<TextAttachmentUpload[]>([])
  const failed = ref<File[]>([])
  const pending = ref(false)
  const error = ref<string | null>(null)
  let generation = 0

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
    if (!files.length || pending.value || disabled()) return
    if (exceedsAttachmentCount(attachments.value.length, failed.value.length, files.length)) {
      error.value = 'К сообщению можно прикрепить не более 10 файлов.'
      return
    }
    const target = channelId()
    const version = generation
    pending.value = true
    error.value = null
    emit('pending', true)
    try {
      for (const file of files) {
        try {
          const uploaded = await uploadFile(target, file)
          if (version !== generation || target !== channelId()) return
          attachments.value = [...attachments.value, uploaded]
          emit('change', [...attachments.value])
        } catch (cause) {
          if (version !== generation || target !== channelId()) return
          failed.value = [...failed.value, file]
          error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить вложение.'
        }
      }
    } finally {
      if (version === generation && target === channelId()) {
        pending.value = false
        emit('pending', false)
      }
    }
  }

  function addFiles(event: Event): void {
    const input = event.currentTarget as HTMLInputElement
    const files = Array.from(input.files ?? [])
    input.value = ''
    void upload(files)
  }

  async function retry(): Promise<void> {
    if (!failed.value.length || pending.value || disabled()) return
    const files = failed.value
    failed.value = []
    await upload(files)
  }

  return { attachments, failed, pending, error, clear, upload, addFiles, retry }
}
