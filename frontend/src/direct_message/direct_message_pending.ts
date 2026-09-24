import type { DirectMessageHistoryItem, DirectMessageRequest } from './direct_message_client'

export interface PendingDirectMessageSend {
  directMessageId: string
  authorId: string
  body: string
  replyToId?: string
  mentionUserIds: string[]
  request?: DirectMessageRequest
  sendStatus: 'sending' | 'failed'
}

export type DirectMessageDisplayItem = DirectMessageHistoryItem & { sendStatus?: 'sending' | 'failed' }

export function pendingDirectMessage(id: string, draft: PendingDirectMessageSend): DirectMessageDisplayItem {
  return {
    id: `optimistic:${id}`, directMessageId: draft.directMessageId, authorId: draft.authorId,
    clientMessageId: id, body: draft.body, replyToId: draft.replyToId,
    createdAt: new Date().toISOString(), revision: 0, deleted: false, mentionUserIds: draft.mentionUserIds, sendStatus: draft.sendStatus,
  }
}

export function pendingDirectMessageKey(draft: PendingDirectMessageSend): string {
  return JSON.stringify([draft.directMessageId, draft.body, draft.replyToId, draft.mentionUserIds])
}
