import type { RealtimeEvent } from '../../realtime/realtime_client'
import { loadMessagePage } from '../../conversation/message_client'
import { loadDirectMessageHistory } from '../../direct_message/direct_message_client'
export async function messageMentionsAccount(event:RealtimeEvent,account:string):Promise<boolean> {
  const id=event.payload.message_id
  if (typeof id!=='string') return false
  const channel=event.payload.channel_id, dm=event.payload.direct_message_id
  try {
    const page=event.kind==='message.created' && typeof channel==='string'
      ? await loadMessagePage(channel,undefined,undefined,id)
      : event.kind==='direct_message.message_created' && typeof dm==='string'
        ? await loadDirectMessageHistory(dm,undefined,undefined,id) : null
    const message=page?.messages.find(item=>item.id===id)
    return Boolean(message && !message.deleted && message.mentionUserIds.includes(account))
  } catch { return false }
}
