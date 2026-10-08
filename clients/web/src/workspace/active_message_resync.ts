export function shouldRefreshTextHistory(event: { kind: string; payload: Record<string, unknown> }, channelId: string | null, hasSelectedDirectMessage: boolean): boolean {
  return !hasSelectedDirectMessage && Boolean(channelId) && (event.kind === 'message.created' || event.kind === 'message.updated' || event.kind === 'message.deleted') && event.payload.channel_id === channelId
}

export function applyDeletedMessageHint(event: { kind: string; payload: Record<string, unknown> }, histories: {
  messages: { channelId: string | null; applyDeletedHint?(channelId: string, messageId: string): void }
  directMessages: { directMessageId: string | null; applyDeletedHint?(directMessageId: string, messageId: string): void }
}): void {
  const { kind, payload } = event
  if (kind === 'message.deleted' && shouldRefreshTextHistory(event, histories.messages.channelId, Boolean(histories.directMessages.directMessageId))) {
    histories.messages.applyDeletedHint?.(payload.channel_id as string, payload.message_id as string)
  } else if (kind === 'direct_message.message_deleted' && histories.directMessages.directMessageId === payload.direct_message_id) {
    histories.directMessages.applyDeletedHint?.(payload.direct_message_id as string, payload.message_id as string)
  }
}
