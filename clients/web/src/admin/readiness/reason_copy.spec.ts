import { describe, expect, it } from 'vitest'
import { readinessProbeReason, readinessProbeStatus } from './reason_copy'

describe('readiness probe copy', () => {
  it('maps bounded backend reasons to contextual Russian messages', () => {
    expect(readinessProbeReason('database_unavailable')).toBe('Не удалось проверить PostgreSQL.')
    expect(readinessProbeReason('sfu_unavailable')).toBe('Не удалось проверить LiveKit.')
    expect(readinessProbeReason('statfs_unavailable')).toBe('Не удалось проверить свободное место в хранилище.')
    expect(readinessProbeReason('insufficient_space')).toBe('Недостаточно места для новых вложений.')
    expect(readinessProbeReason('invalid_measurement')).toBe('Получены некорректные данные о свободном месте.')
    expect(readinessProbeReason('busy')).toBe('Проверка уже выполняется.')
    expect(readinessProbeReason('timeout')).toBe('Проверка не завершилась вовремя.')
  })

  it('never exposes an unknown backend reason and omits an empty reason', () => {
    expect(readinessProbeReason('storage-secret-id')).toBe('Причина проверки недоступна.')
    expect(readinessProbeReason('')).toBeNull()
    expect(readinessProbeReason(undefined)).toBeNull()
  })

  it('uses consistent fresh and stale status labels', () => {
    expect(readinessProbeStatus('ready', false)).toBe('Готово')
    expect(readinessProbeStatus('failed', false)).toBe('Не готово')
    expect(readinessProbeStatus('unknown', false)).toBe('Неизвестно')
    expect(readinessProbeStatus('ready', true)).toBe('Устарело')
  })
})
