import { apiBaseUrl } from '../config/runtime'

export function directMessageAttachmentDownloadUrl(directMessageId: string, attachmentId: string): string {
  if (!directMessageId || !attachmentId) throw new Error('Некорректное вложение.')
  return `${apiBaseUrl}/direct-messages/${encodeURIComponent(directMessageId)}/attachments/${encodeURIComponent(attachmentId)}`
}

export function directMessageAttachmentPreviewUrl(directMessageId: string, attachmentId: string): string {
  return `${directMessageAttachmentDownloadUrl(directMessageId, attachmentId)}/preview`
}
