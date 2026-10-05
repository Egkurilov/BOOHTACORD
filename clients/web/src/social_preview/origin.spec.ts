import { describe, expect, it } from 'vitest'
import { resolvePublicOrigin } from './origin'

describe('social preview public origin', () => {
  it('normalizes an explicitly configured production origin', () => {
    expect(resolvePublicOrigin('https://V.BOOTYBAY.RU/', 'production')).toBe('https://v.bootybay.ru')
  })
  it('requires a secure origin in production', () => {
    for (const value of [undefined, '', 'http://v.bootybay.ru', 'https://u:p@v.bootybay.ru', 'https://v.bootybay.ru/path', 'https://v.bootybay.ru/?q=x', 'https://v.bootybay.ru/#x', 'https://v.bootybay.ru:0']) {
      expect(() => resolvePublicOrigin(value, 'production')).toThrow()
    }
  })
  it('leaves social URLs relative in development unless a local origin is supplied', () => {
    expect(resolvePublicOrigin(undefined, 'development')).toBe('')
    expect(resolvePublicOrigin('http://localhost:8088/', 'development')).toBe('http://localhost:8088')
  })
})
