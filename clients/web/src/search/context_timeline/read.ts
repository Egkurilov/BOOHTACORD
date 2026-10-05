import { useVisibleRead } from '../../conversation/use_visible_read'
import { advanceTextReadIfVisible } from '../../conversation/text_read_gate'
import { advanceReadIfVisible } from '../../direct_message/direct_message_read_gate'

export function useContextRead(props: { kind: 'CHANNEL' | 'DIRECT_MESSAGE'; conversationId: string; unread?: boolean; active?: boolean },
  messages: () => { id: string }[], ready: () => boolean, refresh: () => void) {
  return useVisibleRead({ conversationId: () => props.conversationId, loadedConversationId: () => props.conversationId,
    messages, canRead: () => Boolean(props.unread && props.active && ready()), refreshCounters: refresh,
    advance: (id, messageId) => props.kind === 'CHANNEL'
      ? advanceTextReadIfVisible({ activeChannelId: props.conversationId, renderedChannelId: id, newestDisplayedMessageId: messageId, visibilityState: document.visibilityState })
      : advanceReadIfVisible({ activeDirectMessageId: props.conversationId, renderedDirectMessageId: id, newestDisplayedMessageId: messageId, visibilityState: document.visibilityState }),
  })
}
