import type { WorkspaceRealtimeStores } from '../workspace_realtime'
import type { RealtimeEvent } from '../../realtime/realtime_client'
export async function refreshEditedHints(stores: WorkspaceRealtimeStores, events: RealtimeEvent[]): Promise<void> {
  const text = new Set<string>(), direct = new Set<string>()
  for (const event of events) {
    if (['message.updated', 'message.deleted'].includes(event.kind)
      && event.payload.channel_id === stores.messages.channelId) text.add(event.payload.message_id as string)
    if (['direct_message.message_updated', 'direct_message.message_deleted'].includes(event.kind)
      && event.payload.direct_message_id === stores.directMessages.directMessageId) direct.add(event.payload.message_id as string)
  }
  if (text.size && stores.messages.refreshMessages) {
    await stores.messages.refreshMessages([...text])
    if (stores.messages.error) throw new Error(stores.messages.error)
  }
  if (direct.size && stores.directMessages.refreshMessages) {
    await stores.directMessages.refreshMessages([...direct])
    if (stores.directMessages.error) throw new Error(stores.directMessages.error)
  }
}
