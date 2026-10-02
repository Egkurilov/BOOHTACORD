import { afterEach, describe, expect, it, vi } from 'vitest'
import { loadRnnoiseAssets } from './rnnoise_loader'
afterEach(() => vi.unstubAllGlobals())
describe('RNNoise same origin manifest guard', () => {
  it('rejects external locations before any network request', async () => {
    vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
    const fetcher = vi.fn(); vi.stubGlobal('fetch', fetcher)
    await expect(loadRnnoiseAssets('https://third.test/noise.json')).rejects.toThrow('same origin')
    expect(fetcher).not.toHaveBeenCalled()
  })
  it('rejects HTML fallback assets and evicts failed loads', async () => {
    vi.stubGlobal('window', { location: { origin: 'https://voice.test' } })
    const fetcher = vi.fn().mockResolvedValue(new Response('<html>', { headers: { 'content-type': 'text/html' } }))
    vi.stubGlobal('fetch', fetcher)
    await expect(loadRnnoiseAssets('/bad-manifest')).rejects.toThrow('manifest unavailable')
    await expect(loadRnnoiseAssets('/bad-manifest')).rejects.toThrow('manifest unavailable')
    expect(fetcher).toHaveBeenCalledTimes(2)
  })
})
