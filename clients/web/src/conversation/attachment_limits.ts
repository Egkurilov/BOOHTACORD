export const MAX_MESSAGE_ATTACHMENTS = 10
export const MAX_MESSAGE_ATTACHMENT_BYTES = 25_000_000

export function exceedsAttachmentCount(
  uploadedCount: number,
  failedCount: number,
  incomingCount: number,
): boolean {
  return uploadedCount + failedCount + incomingCount > MAX_MESSAGE_ATTACHMENTS
}
