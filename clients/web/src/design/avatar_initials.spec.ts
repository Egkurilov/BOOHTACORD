import { describe, expect, it } from 'vitest'
import { avatarInitials } from './avatar_initials'

describe('avatar initials', () => {
  it('takes two Unicode letters from a display name', () => {
    expect(avatarInitials('Alex')).toBe('AL')
    expect(avatarInitials('Егор')).toBe('ЕГ')
    expect(avatarInitials('  Daria')).toBe('DA')
    expect(avatarInitials('')).toBe('У')
  })
})
