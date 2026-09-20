import { advanceDirectMessageReadCursor } from './direct_message_client'

export interface ReadGateInput {
  activeDirectMessageId: string | null
  renderedDirectMessageId: string | null
  newestDisplayedMessageId?: string
  visibilityState: string
}

export type ReadCursorAdvancer = (directMessageId: string, messageId: string) => Promise<unknown>

export async function advanceReadIfVisible(input: ReadGateInput, advance: ReadCursorAdvancer = advanceDirectMessageReadCursor): Promise<boolean> {
  if (input.visibilityState !== 'visible' || input.activeDirectMessageId !== input.renderedDirectMessageId || !input.renderedDirectMessageId || !input.newestDisplayedMessageId) return false
  await advance(input.renderedDirectMessageId, input.newestDisplayedMessageId)
  return true
}
