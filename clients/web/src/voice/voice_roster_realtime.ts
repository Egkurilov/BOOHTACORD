import { ref } from 'vue'

import { apiBaseUrl } from '../config/runtime'
import { parseVoiceRosters, type VoiceRoomRoster } from './voice_roster_client'

export interface VoiceRosterEvents {
  onmessage: ((event: { data: string }) => void) | null
  onerror: (() => void) | null
  addEventListener(type: string, listener: EventListener): void
  close(): void
}

export function createVoiceRosterReconnectGate(alreadyConnected = false): () => boolean {
  let connectedOnce = alreadyConnected
  return () => {
    if (!connectedOnce) {
      connectedOnce = true
      return false
    }
    return true
  }
}

export function createVoiceRosterRealtime(
  open: (url: string) => VoiceRosterEvents = (url) => new EventSource(url) as unknown as VoiceRosterEvents,
  onSessionExpired: () => void = () => undefined,
) {
  const channels = ref<VoiceRoomRoster[] | null>(null)
  const error = ref<string | null>(null)
  const lastUpdatedAt = ref<number | null>(null)
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
    const currentSource = open(`${apiBaseUrl}/voice/rosters/events`)
    source = currentSource
    currentSource.onmessage = (event) => {
      if (generation !== currentGeneration) return
      try {
        channels.value = parseVoiceRosters(JSON.parse(event.data))
        lastUpdatedAt.value = Date.now()
        error.value = null
        clearStaleTimer()
      } catch {
        channels.value = null
        error.value = 'Сервер вернул некорректный состав голосовых каналов.'
      }
    }
    currentSource.addEventListener('session-expired', () => {
      if (generation !== currentGeneration) return
      generation++
      currentSource.close()
      channels.value = null
      lastUpdatedAt.value = null
      error.value = null
      clearStaleTimer()
      onSessionExpired()
    })
    currentSource.onerror = () => {
      if (generation !== currentGeneration) return
      error.value = 'Нет связи со списком голосовых каналов. Восстанавливаем соединение.'
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
    lastUpdatedAt.value = null
    error.value = null
  }

  function start(): void {
    if (source === null) reconnect()
  }

  return { channels, error, lastUpdatedAt, reconnect, start, stop }
}
