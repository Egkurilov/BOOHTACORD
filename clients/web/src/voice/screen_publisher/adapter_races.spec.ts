import { describe, expect, it, vi } from 'vitest'
import { setup } from './adapter_fixture'

describe('screen publisher cleanup races', () => {
  it('returns cleanup-pending for a picker and cleans its late capture once', async () => {
    const f = setup(); let finish!: () => void
    vi.mocked(f.port.start).mockImplementationOnce(() => new Promise(resolve => { finish = () => { f.setPublished(f.track); resolve(f.track) } }))
    const start = f.adapter.start('P1080_30'); await Promise.resolve()
    await expect(f.adapter.stop()).resolves.toBe('cleanup-pending')
    await expect(f.adapter.stop()).resolves.toBe('cleanup-pending')
    finish(); expect(await start.catch(e => e.outcome)).toBe('cancel')
    await vi.waitFor(() => expect(f.port.stop).toHaveBeenCalledWith(f.track))
    expect(f.port.currentTrack()).toBeUndefined(); expect(f.port.start).toHaveBeenCalledOnce()
    expect(f.port.stop).toHaveBeenCalledTimes(2)
    expect(f.port.stop).toHaveBeenNthCalledWith(1, undefined)
    expect(f.port.stop).toHaveBeenNthCalledWith(2, f.track)
  })
  it('cleans a started capture when binding validation or diagnostics fail', async () => {
    const mismatch = setup(); vi.mocked(mismatch.port.currentTrack).mockReturnValueOnce({ id: 'other' })
    await expect(mismatch.adapter.start('P1080_30')).rejects.toMatchObject({ outcome: 'failure' })
    expect(mismatch.adapter.active).toBeUndefined(); expect(mismatch.port.stop).toHaveBeenCalledWith(mismatch.track)
    expect(mismatch.port.currentTrack()).toBeUndefined()
    const diagnostics = setup(); vi.mocked(diagnostics.port.diagnostics).mockRejectedValueOnce(new Error('diagnostics failed'))
    await expect(diagnostics.adapter.start('P1080_30')).rejects.toMatchObject({ outcome: 'failure' })
    expect(diagnostics.adapter.active).toBeUndefined(); expect(diagnostics.port.stop).toHaveBeenCalledWith(diagnostics.track)
    expect(diagnostics.port.currentTrack()).toBeUndefined()
  })
  it('cleans partial SDK state when start rejects before returning its capture', async () => {
    const f = setup()
    vi.mocked(f.port.start).mockImplementationOnce(async () => { f.setPublished(f.track); throw new Error('partial publish') })
    await expect(f.adapter.start('P1080_30')).rejects.toMatchObject({ outcome: 'failure' })
    expect(f.port.stop).toHaveBeenCalledWith(undefined)
    expect(f.port.currentTrack()).toBeUndefined()
  })
  it('rebinds the same capture after the SDK republishes it during reconnect', async () => {
    const f = setup(); await f.adapter.start('P1080_30')
    f.republish()
    await f.adapter.update('P720_30')
    expect(f.port.currentTrack()).toBe(f.track)
    expect(f.calls.slice(-3)).toEqual(['capture:P720_30', 'unpublish', 'publish:P720_30'])
  })
  it('makes completed stop idempotent', async () => {
    const f = setup(); await f.adapter.start('P1080_30')
    await expect(f.adapter.stop()).resolves.toBe('complete'); await expect(f.adapter.stop()).resolves.toBe('complete')
    expect(f.port.stop).toHaveBeenCalledOnce(); expect(f.port.currentTrack()).toBeUndefined()
  })
})
