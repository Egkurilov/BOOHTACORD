import { beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'

import { useSearchFilters } from './state'

describe('search filters', () => {
  beforeEach(() => setActivePinia(createPinia()))

  it('retains selected filters for a reopened search panel', () => {
    const firstPanel = useSearchFilters()
    firstPanel.authorId = '11111111-1111-4111-8111-111111111111'
    firstPanel.attachment = 'without'

    const reopenedPanel = useSearchFilters()
    expect(reopenedPanel.authorId).toBe('11111111-1111-4111-8111-111111111111')
    expect(reopenedPanel.attachment).toBe('without')
  })

  it('starts empty for a fresh authenticated store set', () => {
    const filters = useSearchFilters()
    expect(filters.authorId).toBe('')
    expect(filters.attachment).toBe('any')
  })
})
