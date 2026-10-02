import { afterEach, describe, expect, it, vi } from 'vitest'
import { rnnoiseReleaseEnabled } from './capabilities'
afterEach(() => vi.unstubAllEnvs())
describe('RNNoise release capability', () => {
  it('offers RNNoise opt-in only while enabled at build time', () => {
    vi.stubEnv('VITE_RNNOISE_ENABLED', 'true'); expect(rnnoiseReleaseEnabled()).toBe(true)
    vi.stubEnv('VITE_RNNOISE_ENABLED', 'false'); expect(rnnoiseReleaseEnabled()).toBe(false)
  })
})
