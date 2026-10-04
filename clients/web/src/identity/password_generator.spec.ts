import { afterEach, describe, expect, it, vi } from 'vitest'

import { generateSecurePassword, generatedPasswordLength } from './password_generator'

const sourceFrom = (values: number[]) => {
  let index = 0
  return (bytes: Uint8Array): void => { bytes[0] = values[index++ % values.length] }
}

describe('secure registration password generator', () => {
  afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals() })
  it('creates a 24-character password with every required character class', () => {
    const password = generateSecurePassword(sourceFrom([1, 2, 3, 4, 5, 6, 7, 8]))
    expect(password.length).toBe(generatedPasswordLength)
    for (const pattern of [/[A-Z]/, /[a-z]/, /\d/, /[!@#$%^&*_+=-]/, /^[A-Za-z0-9!@#$%^&*_+=-]{24}$/]) {
      expect(pattern.test(password)).toBe(true)
    }
    expect(password === generateSecurePassword(sourceFrom([1, 2, 3, 4, 5, 6, 7, 8]))).toBe(true)
  })

  it('rejects biased bytes before selecting an index', () => {
    const values = [234, 255, 233, 234, 255, 233, 250, 255, 249, 252, 255, 251, 222, 255, 221]
    let calls = 0
    const password = generateSecurePassword(bytes => { bytes[0] = values[calls++] ?? 0 })
    expect(calls).toBe(57) // 47 accepted draws plus two rejected bytes for each class and the union.
    for (const char of ['Z', 'z', '9', '=']) expect(password.includes(char)).toBe(true)
  })

  it('uses cryptographic bytes for every choice and shuffle, without Math.random', () => {
    const getRandomValues = vi.fn((bytes: Uint8Array) => { bytes.fill(0); return bytes })
    vi.stubGlobal('crypto', { getRandomValues })
    vi.spyOn(Math, 'random').mockImplementation(() => { throw new Error('Insecure RNG used') })
    expect(generateSecurePassword().length).toBe(24)
    expect(getRandomValues).toHaveBeenCalledTimes(47)
  })

  it('fails closed if Web Crypto is unavailable', () => {
    vi.stubGlobal('crypto', undefined)
    expect(() => generateSecurePassword()).toThrow('Web Crypto is unavailable.')
  })
})

