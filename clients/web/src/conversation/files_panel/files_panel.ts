import { loadMessagePage, type TextMessage } from '../message_client'
import { loadDirectMessageHistory, type DirectMessageHistoryItem } from '../../direct_message/direct_message_client'

export type ConversationFileMessage = Pick<TextMessage | DirectMessageHistoryItem, 'id' | 'createdAt' | 'deleted' | 'attachments'>

export interface ConversationFileItem {
  id: string
  originalName: string
  sizeBytes: number
  messageId: string
  createdAt: string
  typeLabel: string
}

export function loadConversationFilePage(kind: 'CHANNEL' | 'DIRECT_MESSAGE', conversationId: string, before?: string) {
  return kind === 'CHANNEL' ? loadMessagePage(conversationId, before) : loadDirectMessageHistory(conversationId, before)
}

function fileType(name: string): string {
  const extension = name.split('.').pop()?.trim().toLocaleUpperCase('ru-RU')
  return extension && extension !== name.toLocaleUpperCase('ru-RU') ? extension : 'Файл'
}

export function mapConversationFiles(messages: readonly ConversationFileMessage[]): ConversationFileItem[] {
  const unique = new Map<string, ConversationFileItem>()
  for (const message of messages) {
    if (message.deleted) continue
    for (const attachment of message.attachments) {
      if (unique.has(attachment.id)) continue
      unique.set(attachment.id, { ...attachment, messageId: message.id, createdAt: message.createdAt, typeLabel: fileType(attachment.originalName) })
    }
  }
  return [...unique.values()]
}

export function formatFileSize(size: number): string {
  if (size < 1000) return `${size} Б`
  const units = ['КБ', 'МБ']
  let value = size / 1000
  for (const unit of units) {
    if (value < 1000 || unit === 'МБ') return `${new Intl.NumberFormat('ru-RU', { maximumFractionDigits: 1 }).format(value)} ${unit}`
    value /= 1000
  }
  return `${size} Б`
}
