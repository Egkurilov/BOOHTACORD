import { ref } from 'vue'
import type { MemberPresence } from './profile_client'

type PresenceEvent = { kind: string; payload: Record<string, unknown> }

export function useGuildPresence() {
  const onlineUserIDs = ref<Set<string> | null>(null)
  const changes = ref(new Map<string, MemberPresence>())
  const unavailable = ref(false)

  function acceptRealtimeEvent(event: PresenceEvent): boolean {
    if (event.kind === 'presence.snapshot') {
      const ids = event.payload.online_user_ids
      onlineUserIDs.value = Array.isArray(ids) && ids.every((id) => typeof id === 'string') ? new Set(ids) : null
      changes.value = new Map()
      unavailable.value = onlineUserIDs.value === null
      return true
    }
    if (event.kind !== 'presence.changed') return false
    const userID = event.payload.user_id
    const state = event.payload.presence
    if (typeof userID === 'string' && (state === 'online' || state === 'offline')) {
      changes.value = new Map(changes.value).set(userID, state)
    }
    return true
  }

  function resolve(userID: string, fallback: MemberPresence): MemberPresence {
    if (unavailable.value) return 'unknown'
    const changed = changes.value.get(userID)
    if (changed) return changed
    if (!onlineUserIDs.value) return fallback
    return onlineUserIDs.value.has(userID) ? 'online' : 'offline'
  }

  function invalidate(): void {
    onlineUserIDs.value = null
    changes.value = new Map()
    unavailable.value = true
  }

  return { acceptRealtimeEvent, invalidate, resolve }
}
