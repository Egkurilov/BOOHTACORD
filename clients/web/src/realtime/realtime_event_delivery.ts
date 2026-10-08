import type { RealtimeEvent } from './realtime_client'
import { notifySocialHint,notifySocialRecovery } from '../conversation/reactions/hints'

export type EventHandler = (event: RealtimeEvent) => void | Promise<void>
type RecoveryHandler = () => void | Promise<void>

const durableKinds = new Set<RealtimeEvent['kind']>([
  'voice.lease_revoked', 'channel.updated', 'message.created', 'message.updated', 'message.deleted',
  'direct_message.message_created', 'direct_message.message_updated', 'direct_message.message_deleted',
  'message.reactions_updated','message.pins_updated','direct_message.reactions_updated',
])

export function createRealtimeDelivery(onEvent: EventHandler, onRecovery: RecoveryHandler | undefined, onFailure: (cause: unknown) => void) {
  let cursor: string | null = null
  let fullResyncNeeded = true
  let busy = false
  let active = true
  const queue: RealtimeEvent[] = []
  const seen = new Set<string>()

  function remember(id: string): void {
    seen.add(id)
    if (seen.size > 2048) seen.delete(seen.values().next().value!)
    cursor = id
  }

  function pump(): void {
    if (!active || busy) return
    while (queue.length) {
      const event = queue.shift()!
      const durable = durableKinds.has(event.kind)
      if (durable && seen.has(event.eventId)) continue
      let work: void | Promise<void>
      try {
        if (event.kind === 'connection.resync_required') {
          cursor = null
          seen.clear()
          fullResyncNeeded = true
          work = onEvent(event)
        } else if (event.kind === 'connection.ready') {
          if (!fullResyncNeeded) continue
          work = onRecovery?.()
        } else {
          notifySocialHint(event)
          work = onEvent(event)
        }
      } catch (cause) { fail(cause); return }
      const complete = () => {
        if (!active) return
        if (durable) remember(event.eventId)
        if (event.kind === 'connection.ready' || event.kind === 'connection.resync_required') fullResyncNeeded = false
        if (event.kind === 'connection.ready' || event.kind === 'connection.resync_required') notifySocialRecovery()
      }
      if (work && typeof work.then === 'function') {
        busy = true
        void Promise.resolve(work).then(() => { complete(); busy = false; pump() }, fail)
        return
      }
      complete()
    }
  }

  function fail(cause: unknown): void {
    busy = false
    queue.length = 0
    cursor = null
    seen.clear()
    fullResyncNeeded = true
    if (active) onFailure(cause)
  }

  return {
    accept(event: RealtimeEvent): void { queue.push(event); pump() },
    cursor(): string | null { return cursor },
    disconnected(): void { if (!cursor) fullResyncNeeded = true },
    reset(): void { active = false; queue.length = 0; cursor = null; seen.clear() },
  }
}
