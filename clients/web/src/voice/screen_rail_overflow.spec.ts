import { describe, expect, it } from 'vitest'

import { hasHorizontalOverflowAhead } from './screen_rail_overflow'

describe('screen rail overflow hint', () => {
  it('shows a hint only while additional cards remain to the right', () => {
    expect(hasHorizontalOverflowAhead({ clientWidth: 400, scrollLeft: 0, scrollWidth: 640 })).toBe(true)
    expect(hasHorizontalOverflowAhead({ clientWidth: 400, scrollLeft: 240, scrollWidth: 640 })).toBe(false)
    expect(hasHorizontalOverflowAhead({ clientWidth: 400, scrollLeft: 0, scrollWidth: 400 })).toBe(false)
  })
})
