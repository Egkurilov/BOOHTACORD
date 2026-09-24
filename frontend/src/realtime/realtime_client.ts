import { apiBaseUrl } from '../config/runtime'

export type RealtimeKind = 'connection.ready' | 'connection.resync_required' | 'voice.lease_revoked' | 'channel.updated' | 'presence.snapshot' | 'presence.changed' | 'message.created'
export interface RealtimeEvent {
  eventId: string
  kind: RealtimeKind
  occurredAt: string
  payload: Record<string, unknown>
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null
}
function uuid(value: unknown): value is string {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value)
}

export function parseRealtimeEvent(value: unknown): RealtimeEvent {
  const source = record(value)
  const kind = source?.kind
  const payload = record(source?.payload)
  if (!source || typeof source.event_id !== 'string' || typeof source.occurred_at !== 'string' || Number.isNaN(Date.parse(source.occurred_at)) || typeof kind !== 'string' || !['connection.ready', 'connection.resync_required', 'voice.lease_revoked', 'channel.updated', 'presence.snapshot', 'presence.changed', 'message.created'].includes(kind) || !payload) {
    throw new Error('Сервер вернул некорректное realtime-событие.')
  }
  if (kind === 'presence.snapshot' && (Object.keys(payload).length !== 1 || !Array.isArray(payload.online_user_ids) || !payload.online_user_ids.every(uuid))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'presence.changed' && (Object.keys(payload).length !== 2 || !uuid(payload.user_id) || (payload.presence !== 'online' && payload.presence !== 'offline'))) throw new Error('Некорректное realtime-событие.')
  return { eventId: source.event_id, kind: kind as RealtimeKind, occurredAt: source.occurred_at, payload }
}

export interface RealtimeLocation { protocol: string; host: string }

export function realtimeURL(location: RealtimeLocation = window.location): string {
  return `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}${apiBaseUrl}/realtime`
}
