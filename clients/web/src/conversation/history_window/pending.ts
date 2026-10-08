import type { MessageRequest, TextMessage, TextMessageAttachment } from '../message_client'

export interface PendingSend {
  retryBlocked?: boolean
  channelId: string
  authorId: string
  body: string
  replyToId?: string
  attachments: TextMessageAttachment[]
  mentionUserIds: string[]
  request?: MessageRequest
  sendStatus?: 'sending' | 'checking' | 'failed'
}

export function pendingMessage(id: string, draft: PendingSend): TextMessage {
  return {
    id: `optimistic:${id}`,
    channelId: draft.channelId,
    authorId: draft.authorId,
    clientMessageId: id,
    body: draft.body,
    replyToId: draft.replyToId,
    revision: 0,
    createdAt: new Date().toISOString(),
    deleted: false,
    attachments: draft.attachments,
    mentionUserIds: draft.mentionUserIds,
    retryBlocked: draft.retryBlocked,
    sendStatus: draft.sendStatus ?? 'failed',
  }
}
