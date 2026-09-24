import { apiBaseUrl } from '../config/runtime'
import { isVoiceLeaseRevocationReason } from '../voice/voice_lease_revocation_reason'

export type RealtimeKind = 'connection.ready' | 'connection.resync_required' | 'voice.lease_revoked' | 'channel.updated' | 'presence.snapshot' | 'presence.changed' | 'message.created' | 'message.updated' | 'message.deleted' | 'direct_message.message_created' | 'direct_message.message_updated' | 'direct_message.message_deleted'
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
function keys(payload: Record<string, unknown>, expected: string[]): boolean {
  return Object.keys(payload).length === expected.length && expected.every((key) => Object.hasOwn(payload, key))
}
function revision(value: unknown): boolean { return typeof value === 'number' && Number.isInteger(value) && value >= 1 }

export function parseRealtimeEvent(value: unknown): RealtimeEvent {
  const source = record(value)
  const kind = source?.kind
  const payload = record(source?.payload)
  if (!source || typeof source.event_id !== 'string' || typeof source.occurred_at !== 'string' || Number.isNaN(Date.parse(source.occurred_at)) || typeof kind !== 'string' || !['connection.ready', 'connection.resync_required', 'voice.lease_revoked', 'channel.updated', 'presence.snapshot', 'presence.changed', 'message.created', 'message.updated', 'message.deleted', 'direct_message.message_created', 'direct_message.message_updated', 'direct_message.message_deleted'].includes(kind) || !payload) {
    throw new Error('Сервер вернул некорректное realtime-событие.')
  }
  if (kind === 'presence.snapshot' && (Object.keys(payload).length !== 1 || !Array.isArray(payload.online_user_ids) || !payload.online_user_ids.every(uuid))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'presence.changed' && (Object.keys(payload).length !== 2 || !uuid(payload.user_id) || (payload.presence !== 'online' && payload.presence !== 'offline'))) throw new Error('Некорректное realtime-событие.')
  if (['message.created', 'message.updated', 'message.deleted'].includes(kind) && (!keys(payload, ['channel_id', 'message_id']) || !uuid(payload.channel_id) || !uuid(payload.message_id))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'direct_message.message_created' && (!keys(payload, ['direct_message_id', 'message_id']) || !uuid(payload.direct_message_id) || !uuid(payload.message_id))) throw new Error('Некорректное realtime-событие.')
  if ((kind === 'direct_message.message_updated' || kind === 'direct_message.message_deleted') && (!keys(payload, ['direct_message_id', 'message_id', 'revision']) || !uuid(payload.direct_message_id) || !uuid(payload.message_id) || !revision(payload.revision))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'channel.updated' && (!keys(payload, ['revision']) || !revision(payload.revision))) throw new Error('Некорректное realtime-событие.')
  if (kind === 'voice.lease_revoked' && (!keys(payload, ['lease_id', 'reason']) || !uuid(payload.lease_id) || !isVoiceLeaseRevocationReason(payload.reason))) throw new Error('Некорректное realtime-событие.')
  return { eventId: source.event_id, kind: kind as RealtimeKind, occurredAt: source.occurred_at, payload }
}

export interface RealtimeLocation { protocol: string; host: string }

export function realtimeURL(location: RealtimeLocation = window.location, after?: string): string {
  const base = `${location.protocol === 'https:' ? 'wss:' : 'ws:'}//${location.host}${apiBaseUrl}/realtime`
  return after ? `${base}?after=${encodeURIComponent(after)}` : base
}
