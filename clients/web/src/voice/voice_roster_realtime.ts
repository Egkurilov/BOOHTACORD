import { ref } from 'vue'

import { apiBaseUrl } from '../config/runtime'
import { parseVoiceRosters, type VoiceRoomRoster } from './voice_roster_client'
import { registerVoiceRosterRetry } from './roster_status/retry_action'

export interface VoiceRosterEvents {
  onmessage: ((event: { data: string }) => void) | null
  onerror: (() => void) | null
  addEventListener(type: string, listener: EventListener): void
  close(): void
}

export type VoiceRosterStatus =
  | 'initial_loading'
  | 'fresh'
  | 'fresh_empty'
  | 'stale_reconnecting'
  | 'unavailable'
  | 'session_expired'

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
  const status = ref<VoiceRosterStatus>('initial_loading')
  const lastUpdatedAt = ref<number | null>(null)
  let source: VoiceRosterEvents | null = null
  let generation = 0
  let staleTimer: ReturnType<typeof setTimeout> | null = null
  let unregisterRetry: (() => void) | null = null

  function clearStaleTimer(): void { if (staleTimer !== null) clearTimeout(staleTimer); staleTimer = null }

  function markUnavailable(currentGeneration: number): void {
    if (generation !== currentGeneration) return
    error.value = '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u0431\u043d\u043e\u0432\u0438\u0442\u044c \u0441\u043e\u0441\u0442\u0430\u0432 \u0433\u043e\u043b\u043e\u0441\u043e\u0432\u044b\u0445 \u043a\u0430\u043d\u0430\u043b\u043e\u0432.'
    status.value = channels.value === null ? 'unavailable' : 'stale_reconnecting'
    if (channels.value !== null && staleTimer === null) {
      staleTimer = setTimeout(() => {
        channels.value = null
        status.value = 'unavailable'
        staleTimer = null
      }, 10_000)
    }
  }

  function reconnect(): void {
    unregisterRetry?.()
    unregisterRetry = registerVoiceRosterRetry(reconnect)
    source?.close()
    const currentGeneration = ++generation
    const currentSource = open(`${apiBaseUrl}/voice/rosters/events`)
    source = currentSource
    currentSource.onmessage = (event) => {
      if (generation !== currentGeneration) return
      try {
        const next = parseVoiceRosters(JSON.parse(event.data))
        channels.value = next
        lastUpdatedAt.value = Date.now()
        status.value = next.length === 0 ? 'fresh_empty' : 'fresh'
        error.value = null
        clearStaleTimer()
      } catch {
        markUnavailable(currentGeneration)
      }
    }
    currentSource.addEventListener('roster-unavailable', () => {
      markUnavailable(currentGeneration)
    })
    currentSource.addEventListener('session-expired', () => {
      if (generation !== currentGeneration) return
      generation++
      currentSource.close()
      channels.value = null
      lastUpdatedAt.value = null
      error.value = null
      status.value = 'session_expired'
      clearStaleTimer()
      unregisterRetry?.(); unregisterRetry = null
      onSessionExpired()
    })
    currentSource.onerror = () => markUnavailable(currentGeneration)
  }

  function stop(): void {
    generation++
    unregisterRetry?.(); unregisterRetry = null
    clearStaleTimer()
    source?.close()
    source = null
    channels.value = null
    lastUpdatedAt.value = null
    error.value = null
    status.value = 'initial_loading'
  }

  function start(): void {
    if (source === null) reconnect()
  }

  return { channels, error, status, lastUpdatedAt, reconnect, start, stop }
}
