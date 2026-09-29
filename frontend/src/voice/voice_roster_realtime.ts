import { ref } from 'vue'

import { apiBaseUrl } from '../config/runtime'
import { parseVoiceRosters, type VoiceRoomRoster } from './voice_roster_client'

export interface VoiceRosterEvents {
  onmessage: ((event: { data: string }) => void) | null
  onerror: (() => void) | null
  close(): void
}

export function createVoiceRosterRealtime(
  open: (url: string) => VoiceRosterEvents = (url) => new EventSource(url) as unknown as VoiceRosterEvents,
) {
  const channels = ref<VoiceRoomRoster[] | null>(null)
  const error = ref<string | null>(null)
  let source: VoiceRosterEvents | null = null
  let generation = 0
  let staleTimer: ReturnType<typeof setTimeout> | null = null

  function clearStaleTimer(): void {
    if (staleTimer !== null) clearTimeout(staleTimer)
    staleTimer = null
  }

  function reconnect(): void {
    source?.close()
    const currentGeneration = ++generation
    source = open(`${apiBaseUrl}/voice/rosters/events`)
    source.onmessage = (event) => {
      if (generation !== currentGeneration) return
      try {
        channels.value = parseVoiceRosters(JSON.parse(event.data))
        error.value = null
        clearStaleTimer()
      } catch {
        channels.value = null
        error.value = 'Сервер вернул некорректный состав голосовых каналов.'
      }
    }
    source.onerror = () => {
      if (generation !== currentGeneration) return
      if (channels.value === null) error.value = 'Нет связи со списком голосовых каналов. Восстанавливаем соединение.'
      if (staleTimer === null) staleTimer = setTimeout(() => {
        if (generation === currentGeneration) {
          channels.value = null
          error.value = 'Нет связи со списком голосовых каналов. Восстанавливаем соединение.'
        }
        staleTimer = null
      }, 10_000)
    }
  }

  function stop(): void {
    generation++
    clearStaleTimer()
    source?.close()
    source = null
    channels.value = null
    error.value = null
  }

  return { channels, error, reconnect, start: reconnect, stop }
}
