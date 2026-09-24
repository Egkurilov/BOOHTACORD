import { describe, expect, it } from 'vitest'

import { validCodePointLength } from './unicode_limits'

describe('Unicode limits shared with the Go API', () => {
  it.each([
    [12, 128], [1, 64], [1, 80], [1, 256], [1, 8000],
  ])('accepts non-BMP code points at %i..%i inclusive', (min, max) => {
    expect(validCodePointLength('😀'.repeat(min), min, max)).toBe(true)
    expect(validCodePointLength('😀'.repeat(max), min, max)).toBe(true)
    expect(validCodePointLength('😀'.repeat(Math.max(0, min - 1)), min, max)).toBe(false)
    expect(validCodePointLength('😀'.repeat(max + 1), min, max)).toBe(false)
  })

  it('counts code points rather than grapheme clusters and never trims passwords', () => {
    expect(validCodePointLength('👩‍💻', 3, 3)).toBe(true)
    expect(validCodePointLength('  😀  ', 5, 5)).toBe(true)
    expect(validCodePointLength('  😀  ', 1, 1)).toBe(false)
  })
})
