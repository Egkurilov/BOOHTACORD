import { afterEach, describe, expect, it } from 'vitest'
import { searchDateRange } from './date_range'

const originalZone = process.env.TZ
afterEach(() => { if (originalZone === undefined) delete process.env.TZ; else process.env.TZ = originalZone })

describe('search local calendar boundaries', () => {
  it.each([
    ['2026-03-08', '2026-03-08T05:00:00.000Z', '2026-03-09T04:00:00.000Z'],
    ['2026-11-01', '2026-11-01T04:00:00.000Z', '2026-11-02T05:00:00.000Z'],
  ])('uses next calendar midnight across DST for %s', (day, createdFrom, createdBefore) => {
    process.env.TZ = 'America/New_York'
    expect(searchDateRange(day, day)).toEqual({ createdFrom, createdBefore })
  })

  it('supports open boundaries and inclusive end date in local UTC calendar', () => {
    process.env.TZ = 'UTC'
    expect(searchDateRange('', '')).toEqual({})
    expect(searchDateRange('2026-10-08', '')).toEqual({ createdFrom: '2026-10-08T00:00:00.000Z' })
    expect(searchDateRange('', '2026-10-08')).toEqual({ createdBefore: '2026-10-09T00:00:00.000Z' })
  })

  it.each([['2026-02-30', ''], ['2026-10-09', '2026-10-08'], ['x', ''], ['', '0000-01-01'], ['', '9999-12-31']])(
    'rejects invalid or reversed calendar dates', (from, to) => {
      expect(() => searchDateRange(from, to)).toThrow()
    },
  )

  it('rejects a local calendar day skipped by a timezone transition', () => {
    process.env.TZ = 'Pacific/Apia'
    expect(() => searchDateRange('2011-12-30', '')).toThrow('корректную дату')
  })
})
