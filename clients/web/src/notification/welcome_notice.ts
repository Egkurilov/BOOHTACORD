import type { RealtimeEvent } from '../realtime/realtime_client'
import { loadMessagePage } from '../conversation/message_client'
export async function welcomeNotice(event: RealtimeEvent): Promise<string | null> {
  if (event.kind !== 'message.created') return null
  try {
    const page = await loadMessagePage(event.payload.channel_id as string, undefined, undefined, event.payload.message_id as string)
    const message = page.messages.find(row => row.id === event.payload.message_id)
    return message?.kind === 'SYSTEM_WELCOME' && !message.deleted ? 'Новый участник в гильдии.' : null
  } catch { return null }
}
