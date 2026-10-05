import { uploadTextAttachment, type TextAttachmentUpload } from './text_attachment_upload_client'
import { createManagedUploadQueue } from './upload_queue/queue'
import { progressRequest } from './upload_queue/transport'
import type { Emit, Upload } from './upload_queue/types'

export function useTextAttachmentQueue(scope: () => string, disabled: () => boolean, emit: Emit<TextAttachmentUpload>, uploadFile = uploadTextAttachment, initial: TextAttachmentUpload[] = []) {
  const upload: Upload<TextAttachmentUpload> = (id, file, control) => uploadFile === uploadTextAttachment
    ? uploadFile(id, file, progressRequest(control)) : uploadFile(id, file)
  return createManagedUploadQueue(scope, disabled, emit, upload, initial)
}
