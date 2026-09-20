import { apiBaseUrl } from '../config/runtime'

export type RealtimeKind = 'connection.ready' | 'connection.resync_required' | 'voice.lease_revoked' | 'channel.updated' | 'message.created'
export interface RealtimeEvent {
  eventId: string
  kind: RealtimeKind
  occurredAt: string
  payload: Record<string, unknown>
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null
}

export function parseRealtimeEvent(value: unknown): RealtimeEvent {
  const source = record(value)
  const kind = source?.kind
  if (!source || typeof source.event_id !== 'string' || typeof source.occurred_at !== 'string' || Number.isNaN(Date.parse(source.occurred_at)) || typeof kind !== 'string' || !['connection.ready', 'connection.resync_required', 'voice.lease_revoked', 'channel.updated', 'message.created'].includes(kind) || !record(source.payload)) {
    throw new Error('Сервер вернул некорректное realtime-событие.')
  }
  return { eventId: source.event_id, kind: kind as RealtimeKind, occurredAt: source.occurred_at, payload: record(source.payload)! }
}

export interface RealtimeLocation { protocol: string; host: string }

export function realtimeURL(location: RealtimeLocation = window.location): string {
  return `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}${apiBaseUrl}/realtime`
}
