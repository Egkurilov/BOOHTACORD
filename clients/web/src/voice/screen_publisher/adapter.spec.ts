import { describe, expect, it, vi } from 'vitest'
import { readFileSync } from 'node:fs'
import { ScreenPublisherOperationError } from './adapter'
import { setup } from './adapter_fixture'
import type { ScreenProfile } from '../screen_profile/policy'
const lifecycle = JSON.parse(readFileSync(new URL('../../../../../contracts/screen-share-publisher-lifecycle-v1.fixtures.json', import.meta.url), 'utf8')) as { outcomes: string[] }

describe('screen publisher operation lifecycle', () => {
  it('reports picker cancellation distinctly from denied capture permission', async () => {
    const cancelled = setup(); vi.mocked(cancelled.port.start).mockResolvedValueOnce(undefined)
    await expect(cancelled.adapter.start('P1080_30')).rejects.toMatchObject({ outcome: 'cancel' })
    const denied = setup(); vi.mocked(denied.port.start).mockRejectedValueOnce(Object.assign(new Error('permission denied'), { name: 'NotAllowedError' }))
    await expect(denied.adapter.start('P1080_30')).rejects.toMatchObject({ outcome: 'failure', operationCause: { name: 'NotAllowedError' } })
    const aborted = setup(); vi.mocked(aborted.port.start).mockRejectedValueOnce(Object.assign(new Error('picker closed'), { name: 'AbortError' }))
    await expect(aborted.adapter.start('P1080_30')).rejects.toMatchObject({ outcome: 'cancel' })
  })
  it('starts once and updates the video while retaining the same capture', async () => {
    const f = setup(); await f.adapter.start('P1080_30'); await f.adapter.update('P720_30')
    expect(f.calls).toEqual(['start', 'capture:P720_30', 'unpublish', 'publish:P720_30'])
    expect(f.port.currentTrack()).toBe(f.track)
  })
  it('coalesces rapid profile changes to the last requested plan', async () => {
    const f = setup(); await f.adapter.start('P720_15')
    const pending = ['P720_30', 'P1080_30', 'P1440_60'].map(p => f.adapter.update(p as ScreenProfile))
    const results = await Promise.allSettled(pending)
    expect(f.calls).toContain('publish:P1440_60')
    expect(f.calls.filter(c => c.startsWith('publish:'))).toEqual(['publish:P1440_60'])
    expect(results.slice(0, 2).map(r => r.status === 'rejected' && r.reason.outcome)).toEqual(['superseded', 'superseded'])
    expect(lifecycle.outcomes).toEqual(['success', 'cancel', 'superseded', 'failure'])
  })
  it('cancels an in-flight update when stop becomes the latest intent', async () => {
    const f = setup(); await f.adapter.start('P1080_30')
    let finish!: () => void
    vi.mocked(f.port.capture).mockImplementationOnce(() => new Promise<void>(resolve => { finish = resolve }))
    const update = f.adapter.update('P720_30'); await Promise.resolve()
    const stop = f.adapter.stop(); finish()
    const outcome = await update.catch(e => e.outcome); await stop
    expect(outcome).toBe('cancel')
    expect(f.port.publish).not.toHaveBeenCalled()
    expect(f.port.stop).toHaveBeenCalledOnce()
  })
  it('resumes from a retained capture when a newer update arrives during unpublish', async () => {
    const f = setup(); await f.adapter.start('P1080_30')
    let finish!: () => void
    vi.mocked(f.port.unpublish).mockImplementationOnce(() => new Promise<void>(resolve => {
      finish = () => { f.setPublished(); resolve() }
    }))
    const first = f.adapter.update('P720_30'); await vi.waitFor(() => expect(f.port.unpublish).toHaveBeenCalled())
    const latest = f.adapter.update('P1440_60'); finish()
    expect(await first.catch(e => e.outcome)).toBe('superseded')
    await latest
    expect(f.calls.slice(-2)).toEqual(['capture:P1440_60', 'publish:P1440_60'])
    expect(f.port.currentTrack()).toBe(f.track)
  })
  it('cleans a publication that finishes after stop was requested', async () => {
    const f = setup(); await f.adapter.start('P1080_30')
    let finish!: () => void
    vi.mocked(f.port.publish).mockImplementationOnce(() => new Promise<void>(resolve => { finish = () => { f.setPublished(f.track); resolve() } }))
    const update = f.adapter.update('P720_30'); await vi.waitFor(() => expect(f.port.publish).toHaveBeenCalled())
    let stopResolved = false
    const stop = f.adapter.stop().then(() => { stopResolved = true })
    await Promise.resolve(); expect(stopResolved).toBe(false); finish()
    const outcome = await update.catch(e => e.outcome); await stop
    expect(outcome).toBe('cancel')
    expect(f.port.stop).toHaveBeenCalledWith(f.track)
    expect(f.port.currentTrack()).toBeUndefined()
  })
  it('restores the previous capture and plan when the replacement publish fails', async () => {
    const f = setup(); await f.adapter.start('P1080_30')
    vi.mocked(f.port.publish).mockRejectedValueOnce(new Error('publish failed'))
    await expect(f.adapter.update('P720_30')).rejects.toMatchObject({ outcome: 'failure', recovery: 'restored' })
    expect(f.calls.slice(-3)).toEqual(['unpublish', 'capture:P1080_30', 'publish:P1080_30'])
    expect(f.port.currentTrack()).toBe(f.track)
  })
  it('reports cleanup-required when restoring the old plan fails', async () => {
    const f = setup(); await f.adapter.start('P1080_30')
    vi.mocked(f.port.publish).mockRejectedValueOnce(new Error('replace failed')).mockRejectedValueOnce(new Error('restore failed'))
    await expect(f.adapter.update('P720_30')).rejects.toBeInstanceOf(ScreenPublisherOperationError)
    expect(f.port.stop).toHaveBeenCalledWith(f.track)
  })
})
