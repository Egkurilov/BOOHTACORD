import type { AuditEvent } from '../../identity/admin_directory_client'

export type AuditScope = 'all' | 'admin' | 'voice'
export interface AuditFilters { scope: AuditScope; from?: string; to?: string; type?: string; actor?: string }
export interface AuditDay { key: string; label: string; events: AuditEvent[] }

export function filterAuditEvents(events: AuditEvent[], filters: AuditFilters): AuditEvent[] {
  const from = filters.from ? new Date(`${filters.from}T00:00:00`).getTime() : -Infinity
  const to = filters.to ? new Date(`${filters.to}T23:59:59.999`).getTime() : Infinity
  return events.filter((event) => {
    const voice = event.event_type.startsWith('VOICE_')
    if (filters.scope === 'voice' && !voice || filters.scope === 'admin' && voice) return false
    if (filters.type && event.event_type !== filters.type) return false
    if (filters.actor && (event.actor_user_id ?? 'system') !== filters.actor) return false
    const at = new Date(event.created_at).getTime()
    return at >= from && at <= to
  })
}

export function appendAuditPage(current: AuditEvent[], next: AuditEvent[]): AuditEvent[] {
  const ids = new Set(current.map(({ id }) => id))
  return [...current, ...next.filter(({ id }) => { if (ids.has(id)) return false; ids.add(id); return true })]
}

export function groupAuditDays(events: AuditEvent[]): AuditDay[] {
  const days: AuditDay[] = []
  for (const event of events) {
    const date = new Date(event.created_at)
    const key = Number.isNaN(date.getTime()) ? 'unknown' : `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`
    const label = key === 'unknown' ? 'Дата неизвестна' : date.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long', year: 'numeric' })
    const last = days.at(-1)
    if (last?.key === key) last.events.push(event)
    else days.push({ key, label, events: [event] })
  }
  return days
}
