import { expect, it, vi } from 'vitest'
import { ScreenAdaptationBinding } from './binding'
import { calibration, fixture, window } from './fixture'

function barrier() { let release!: () => void; const promise = new Promise<void>(done => { release = done }); return { promise, release } }
it('late classified diagnostics cannot cross manual intent, publication, owner or Room boundaries', async () => {
  for (const boundary of ['manual', 'publication', 'owner', 'room', 'stop']) {
    const f = await fixture(), pending = barrier()
    const binding = new ScreenAdaptationBinding(f.adapter, { enabled: true, calibration, now: () => 2000,
      readWindow: async (_diagnostics, context) => { await pending.promise; return window(2000, context.publicationGeneration) } })
    await binding.runtime.step(window(1000, f.port.generation()), 1000)
    const reading = binding.read(() => f.port.diagnostics())
    await Promise.resolve(); await Promise.resolve()
    if (boundary === 'manual') await f.adapter.update('P720_30')
    if (boundary === 'publication') f.republish()
    if (boundary === 'owner') f.current.mockReturnValue({ ...f.current(), owner: {} })
    if (boundary === 'room') f.current.mockReturnValue({ ...f.current(), room: {} })
    if (boundary === 'stop') await f.adapter.stop()
    const calls = vi.mocked(f.port.capture).mock.calls.length
    pending.release()
    expect((await reading).adaptationReason).toBe('stale-owner')
    expect(f.port.capture).toHaveBeenCalledTimes(calls)
  }
})
it('manual intent supersedes pending adaptation through the same serialized writer', async () => {
  const f = await fixture(), pending = barrier()
  await f.runtime.step(window(1000, f.port.generation()), 1000)
  vi.mocked(f.port.capture).mockImplementationOnce(async () => pending.promise)
  const adapting = f.runtime.step(window(2000, f.port.generation()), 2000)
  const manual = f.adapter.update('P720_30')
  pending.release()
  expect(await adapting).toMatchObject({ reason: 'superseded', applied: false })
  await manual
  expect(f.adapter.active?.profile).toBe('P720_30')
  f.runtime.capture()
  expect(f.runtime.state?.ceilingProfile).toBe('P720_30')
})
it('late native writer completion cannot revive stopped or replaced screen ownership', async () => {
  for (const boundary of ['stop', 'owner', 'room']) {
    const f = await fixture(), pending = barrier()
    await f.runtime.step(window(1000, f.port.generation()), 1000)
    vi.mocked(f.port.capture).mockImplementationOnce(async () => pending.promise)
    const adapting = f.runtime.step(window(2000, f.port.generation()), 2000)
    const stopping = boundary === 'stop' ? f.adapter.stop() : undefined
    if (boundary === 'owner') f.current.mockReturnValue({ ...f.current(), owner: {} })
    if (boundary === 'room') f.current.mockReturnValue({ ...f.current(), room: {} })
    pending.release()
    expect((await adapting).applied).toBe(false)
    await stopping
    expect(f.port.publish).not.toHaveBeenCalled()
  }
})
