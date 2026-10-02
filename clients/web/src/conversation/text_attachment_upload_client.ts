import { tracedFetch } from '../telemetry/client_tracing'
import { apiBaseUrl } from '../config/runtime'
import { MessageRequestError, type MessageRequest } from './message_client'
import { MAX_MESSAGE_ATTACHMENT_BYTES } from './attachment_limits'

export interface TextAttachmentUpload {
  id: string
  originalName: string
  sizeBytes: number
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null
}

function text(value: unknown): string | null {
  return typeof value === 'string' ? value : null
}

function attachment(value: unknown): TextAttachmentUpload {
  const source = record(value)
  const id = text(source?.id)
  const originalName = text(source?.original_name)
  const sizeBytes = source?.byte_size
  if (!source || !id || !originalName || !Number.isInteger(sizeBytes) || (sizeBytes as number) < 0 || (sizeBytes as number) > 25_000_000) {
    throw new Error('Сервер вернул некорректные данные вложения.')
  }
  return { id, originalName, sizeBytes: sizeBytes as number }
}

async function checked(response: Response): Promise<unknown> {
  let body: unknown = null
  try { body = await response.json() } catch { /* A bounded status error is sufficient. */ }
  if (response.ok) return body
  const code = text(record(record(body)?.error)?.code) ?? undefined
  throw new MessageRequestError(response.status, code)
}

export async function uploadTextAttachment(channelId: string, file: File, request: MessageRequest = tracedFetch): Promise<TextAttachmentUpload> {
  if (!channelId || !file.name || !Number.isInteger(file.size) || file.size < 0 || file.size > MAX_MESSAGE_ATTACHMENT_BYTES) {
    throw new Error('Файл не соответствует ограничению вложения.')
  }
  const body = new FormData()
  body.append('file', file)
  const response = await request(`${apiBaseUrl}/channels/${encodeURIComponent(channelId)}/attachments`, {
    method: 'POST', credentials: 'same-origin', headers: { accept: 'application/json' }, body,
  })
  return attachment(await checked(response))
}
