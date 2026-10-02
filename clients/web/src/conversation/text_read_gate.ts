import { advanceTextReadCursor } from './text_read_cursor_client'

export function newestServerTextMessageId(messages: { id: string; sendStatus?: 'sending' | 'failed' }[]): string | undefined {
  return messages.find((message) => !message.sendStatus)?.id
}

export interface TextReadGateInput {
  activeChannelId: string | null
  renderedChannelId: string | null
  newestDisplayedMessageId?: string
  visibilityState: string
}

export type TextReadAdvancer = (channelId: string, messageId: string) => Promise<unknown>

export async function advanceTextReadIfVisible(input: TextReadGateInput, advance: TextReadAdvancer = advanceTextReadCursor): Promise<boolean> {
  if (input.visibilityState !== 'visible' || input.activeChannelId !== input.renderedChannelId || !input.renderedChannelId || !input.newestDisplayedMessageId) return false
  await advance(input.renderedChannelId, input.newestDisplayedMessageId)
  return true
}
