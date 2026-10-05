import type { RealtimeEvent } from '../../realtime/realtime_client'

export async function deliverProtectedHintBatch(events: RealtimeEvent[],
  handler: (event: RealtimeEvent, notify?: boolean) => void | Promise<void>): Promise<void> {
  const notified = new Set<string>()
  await Promise.all(events.map(event => {
    const resource = event.kind === 'message.created' ? 'text:'+event.payload.channel_id
      : event.kind === 'direct_message.message_created' ? 'dm:'+event.payload.direct_message_id : null
    const notify = resource === null || !notified.has(resource)
    if (resource) notified.add(resource)
    // A shared unread snapshot formerly notified only the first created hint.
    return handler(event, notify)
  }))
}
