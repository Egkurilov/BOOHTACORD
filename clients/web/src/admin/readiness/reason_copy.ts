import type { Probe } from './client'

const reasonCopy: Record<string, string> = {
  database_unavailable: 'Не удалось проверить PostgreSQL.',
  sfu_unavailable: 'Не удалось проверить LiveKit.',
  statfs_unavailable: 'Не удалось проверить свободное место в хранилище.',
  invalid_measurement: 'Получены некорректные данные о свободном месте.',
  insufficient_space: 'Недостаточно места для новых вложений.',
  busy: 'Проверка уже выполняется.',
  timeout: 'Проверка не завершилась вовремя.',
}

export function readinessProbeReason(reason: string | null | undefined): string | null {
  if (!reason?.trim()) return null
  return reasonCopy[reason] ?? 'Причина проверки недоступна.'
}

export function readinessProbeStatus(status: Probe['status'], stale: boolean): string {
  if (stale) return 'Устарело'
  switch (status) {
    case 'ready': return 'Готово'
    case 'failed': return 'Не готово'
    default: return 'Неизвестно'
  }
}
