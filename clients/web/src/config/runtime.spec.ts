import { describe, expect, it } from 'vitest'

import { apiBaseUrl } from './runtime'

describe('runtime configuration', () => {
  it('uses the versioned same-origin API prefix', () => {
    expect(apiBaseUrl).toBe('/api/v1')
  })
})
