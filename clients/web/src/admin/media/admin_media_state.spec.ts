import { describe, expect, it } from 'vitest'
import type { AdminScreenSample } from './admin_media_client'
import { selectAdminMediaState } from './admin_media_state'

const now = Date.parse('2026-10-04T12:00:00Z')
const sample = (time: string): AdminScreenSample => ({
  platform: 'desktop_web', direction: 'sender', state: 'playing', sampled_at_utc: time,
})

describe('administrator media freshness', () => {
  it('distinguishes no reports, stale reports and fresh reports', () => {
    expect(selectAdminMediaState([], now, null, null)).toEqual({ kind: 'empty', freshCount: 0 })
    expect(selectAdminMediaState([sample('2026-10-04T11:58:00Z')], now, null, null)).toEqual({ kind: 'stale', freshCount: 0 })
    expect(selectAdminMediaState([sample('2026-10-04T11:59:30Z')], now, null, null)).toEqual({ kind: 'populated', freshCount: 1 })
  })

  it('remembers an earlier report after an empty refresh and prioritizes errors', () => {
    expect(selectAdminMediaState([], now, now - 120_000, null).kind).toBe('stale')
    expect(selectAdminMediaState([sample('2026-10-04T11:59:30Z')], now, now - 120_000, 'Ошибка').kind).toBe('error')
  })
})
