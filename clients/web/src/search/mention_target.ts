import type { TopologyChannel } from '../channel/topology_client'
import type { MentionInboxItem } from './mentions_inbox_client'
import type { SearchTarget } from './search_target_store'

export function targetForMention(
  mention: MentionInboxItem,
  channels: Pick<TopologyChannel, 'id' | 'kind'>[],
  accessibleDirectMessageIDs: string[],
): SearchTarget | null {
  if (mention.kind === 'CHANNEL') {
    return channels.some((channel) => channel.id === mention.conversationId && channel.kind === 'TEXT')
      ? { kind: 'CHANNEL', conversationId: mention.conversationId, messageId: mention.messageId }
      : null
  }
  return accessibleDirectMessageIDs.includes(mention.conversationId)
    ? { kind: 'DIRECT_MESSAGE', conversationId: mention.conversationId, messageId: mention.messageId }
    : null
}
