import type { TextMessageAttachment } from '../conversation/message_client'

export function parseDirectMessageAttachments(value: unknown, deleted = false): TextMessageAttachment[] {
  if (value === undefined) return []
  if (!Array.isArray(value) || (deleted && value.length)) throw new Error('Сервер вернул некорректные данные вложения.')
  return value.map((candidate) => {
    if (typeof candidate !== 'object' || candidate === null || Array.isArray(candidate)) throw new Error('Сервер вернул некорректные данные вложения.')
    const item = candidate as Record<string, unknown>
    if (typeof item.id !== 'string' || !item.id || typeof item.original_name !== 'string' || !item.original_name
      || !Number.isInteger(item.byte_size) || (item.byte_size as number) < 0 || (item.byte_size as number) > 25_000_000) {
      throw new Error('Сервер вернул некорректные данные вложения.')
    }
    return { id: item.id, originalName: item.original_name, sizeBytes: item.byte_size as number }
  })
}
