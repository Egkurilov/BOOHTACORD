import { describe, expect, it } from 'vitest'
import { avatarBackground, avatarForeground } from './avatar_color'

describe('V2 identity avatar tones', () => {
  it('keeps the existing identity background and pairs it with the handoff foreground', () => {
    expect(avatarBackground('fixture-6')).toBe('var(--gc-avatar-blue)')
    expect(avatarForeground('fixture-6')).toBe('#A5F2F0')
    expect(avatarForeground('fixture-2')).toBe('#FFD5A8')
    expect(avatarForeground('fixture-3')).toBe('#E3DCFF')
    expect(avatarForeground('fixture-0')).toBe('#E9CBFF')
  })
})
