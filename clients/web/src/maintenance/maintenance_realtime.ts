import { ref } from 'vue'

import { apiBaseUrl } from '../config/runtime'

export interface MaintenanceEvents {
  onmessage: ((event: { data: string }) => void) | null
  onerror: (() => void) | null
  close(): void
}

export function createMaintenanceRealtime(
  open: (url: string) => MaintenanceEvents = (url) => new EventSource(url) as unknown as MaintenanceEvents,
) {
  const active = ref(false)
  let source: MaintenanceEvents | null = null

  function start(): void {
    if (source !== null) return
    const currentSource = open(`${apiBaseUrl}/maintenance/events`)
    source = currentSource
    currentSource.onmessage = (event) => {
      try {
        const value: unknown = JSON.parse(event.data)
        if (typeof value !== 'object' || value === null || Array.isArray(value)) return
        const state = (value as Record<string, unknown>).active
        if (typeof state === 'boolean') active.value = state
      } catch {
        // Ignore malformed frames and keep the last known public state.
      }
    }
  }

  function stop(): void {
    source?.close()
    source = null
  }

  return { active, start, stop }
}
