import { ref } from 'vue'

import { loadVoiceRosters, type VoiceRoomRoster } from './voice_roster_client'

export function createVoiceRosterPolling(load: () => Promise<VoiceRoomRoster[]> = loadVoiceRosters, intervalMs = 10_000) {
  const channels = ref<VoiceRoomRoster[] | null>(null)
  const error = ref<string | null>(null)
  let active = false
  let generation = 0
  let timer: ReturnType<typeof setInterval> | null = null
  let current: Promise<void> | null = null

  async function refresh(): Promise<void> {
    if (!active) return
    if (current) return current
    const ownGeneration = generation
    const operation = (async () => {
      try {
        const snapshot = await load()
        if (active && generation === ownGeneration) { channels.value = snapshot; error.value = null }
      } catch (cause) {
        if (active && generation === ownGeneration) {
          channels.value = null
          error.value = cause instanceof Error ? cause.message : 'Не удалось обновить состав голосовых каналов.'
        }
      }
    })()
    current = operation
    try { await operation } finally { if (generation === ownGeneration) current = null }
  }

  function start(): void {
    if (active) return
    active = true
    generation++
    void refresh()
    timer = setInterval(() => { void refresh() }, intervalMs)
  }

  function stop(): void {
    active = false
    generation++
    if (timer) clearInterval(timer)
    timer = null
    current = null
    channels.value = null
    error.value = null
  }

  return { channels, error, refresh, start, stop }
}
