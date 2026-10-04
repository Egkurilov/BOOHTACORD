import { describe, expect, it } from 'vitest'

import { generateSecurePassword, generatedPasswordLength } from './password_generator'

const sourceFrom = (values: number[]) => {
  let index = 0
  return (bytes: Uint8Array): void => { bytes[0] = values[index++ % values.length] }
}

describe('secure registration password generator', () => {
  it('creates a 24-character password with every required character class', () => {
    const password = generateSecurePassword(sourceFrom([1, 2, 3, 4, 5, 6, 7, 8]))
    expect(password).toHaveLength(generatedPasswordLength)
    expect(password).toMatch(/[A-Z]/); expect(password).toMatch(/[a-z]/); expect(password).toMatch(/\d/); expect(password).toMatch(/[!@#$%^&*_+=-]/)
    expect(password).toMatch(/^[A-Za-z0-9!@#$%^&*_+=-]+$/)
  })

  it('rejects biased bytes before selecting an index', () => {
    const password = generateSecurePassword(sourceFrom([255, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9]))
    expect(password).toHaveLength(24)
  })
})

