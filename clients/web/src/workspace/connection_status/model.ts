import type { RealtimeState } from '../../realtime/realtime_store'
import type { VoiceConnectionState } from '../../voice/connection_store'

export function connectionStatus(chat: RealtimeState, voice: VoiceConnectionState,
  rosterAvailable: boolean, lastUpdatedAt: number | null, now: number) {
  const age = lastUpdatedAt === null ? '' : ` · ${Math.max(0, Math.floor((now-lastUpdatedAt)/1000))} с. назад`
  return {
    chat: chat === 'CONNECTED' ? 'Чат подключён' : 'Чат обновляется',
    voice: voice === 'CONNECTED' || voice === 'LISTENER' ? 'Голос подключён'
      : voice === 'JOINING' || voice === 'RECONNECTING' ? 'Голос восстанавливается' : 'Голос не подключён',
    roster: (rosterAvailable ? 'Состав обновлён' : lastUpdatedAt !== null ? 'Состав устарел' : 'Состав недоступен')+age,
  }
}
