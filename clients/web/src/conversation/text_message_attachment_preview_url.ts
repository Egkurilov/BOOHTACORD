import { apiBaseUrl } from '../config/runtime'

export function textMessageAttachmentPreviewUrl(channelId: string, attachmentId: string): string {
  if (!channelId || !attachmentId) throw new Error('Некорректное вложение.')
  return `${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/attachments/${encodeURIComponent(attachmentId)}/preview`
}
