export function shouldRefreshTextHistory(event: { kind: string; payload: Record<string, unknown> }, channelId: string | null, hasSelectedDirectMessage: boolean): boolean {
  return !hasSelectedDirectMessage && Boolean(channelId) && (event.kind === 'message.created' || event.kind === 'message.updated' || event.kind === 'message.deleted') && event.payload.channel_id === channelId
}
