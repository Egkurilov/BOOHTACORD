import { beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

import { useSearchFilters } from './state'
import { clearAuthenticatedState } from '../../identity/clear_authenticated_state'

describe('search filters', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('retains selected filters for a reopened search panel', () => {
    const firstPanel = useSearchFilters()
    firstPanel.authorId = '11111111-1111-4111-8111-111111111111'
    firstPanel.attachment = 'without'
    firstPanel.dateFrom = '2026-10-08'
    firstPanel.dateTo = '2026-10-09'

    const reopenedPanel = useSearchFilters()
    expect(reopenedPanel.authorId).toBe('11111111-1111-4111-8111-111111111111')
    expect(reopenedPanel.attachment).toBe('without')
    expect(reopenedPanel.dateFrom).toBe('2026-10-08')
    expect(reopenedPanel.dateTo).toBe('2026-10-09')
  })

  it('starts empty for a fresh authenticated store set', () => {
    const filters = useSearchFilters()
    expect(filters.authorId).toBe('')
    expect(filters.attachment).toBe('any')
    expect(filters.dateFrom).toBe('')
    expect(filters.dateTo).toBe('')
  })

  it('clears dates on reset and across the authenticated logout boundary', () => {
    const filters = useSearchFilters()
    filters.dateFrom = '2026-10-08'
    filters.dateTo = '2026-10-09'
    filters.reset()
    expect([filters.dateFrom, filters.dateTo]).toEqual(['', ''])
    filters.dateFrom = '2026-10-08'
    filters.dateTo = '2026-10-09'
    clearAuthenticatedState()
    const nextAccount = useSearchFilters()
    expect([nextAccount.authorId, nextAccount.attachment, nextAccount.dateFrom, nextAccount.dateTo]).toEqual(['', 'any', '', ''])
  })
})
