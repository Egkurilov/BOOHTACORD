import { expect, it } from 'vitest'
import { ScreenAdaptationRuntime } from './runtime'
import { fixture, window } from './fixture'

it('default off or missing calibration never mutates the real serialized writer', async () => {
  const f = await fixture(), generation = f.port.generation()
  for (const options of [{}, { enabled: true }]) {
    const runtime = new ScreenAdaptationRuntime(f.adapter, options)
    await runtime.step(window(1000, generation), 1000)
    await runtime.step(window(2000, generation), 2000)
  }
  expect(f.port.capture).not.toHaveBeenCalled()
})
it('classified pressure uses the existing writer once and retains manual ceiling through recovery', async () => {
  const f = await fixture(), generation = f.port.generation()
  await f.runtime.step(window(1000, generation), 1000)
  expect(await f.runtime.step(window(2000, generation), 2000)).toMatchObject({ reason: 'downgrade-pressure', applied: true })
  expect(f.adapter.active?.profile).toBe('P720_60')
  expect(f.runtime.state?.ceilingProfile).toBe('P1080_60')
  expect(f.port.capture).toHaveBeenCalledTimes(1)
  const clear = (at: number) => { const sample = window(at, f.port.generation()); return { ...sample, signals: sample.signals.map(signal => ({ ...signal, condition: 'clear' as const })) } }
  for (const at of [3000, 7000, 11000, 13000]) await f.runtime.step(clear(at), at)
  expect(f.adapter.active?.profile).toBe('P1080_60')
  expect(f.port.capture).toHaveBeenCalledTimes(2)
})
it('hidden static unknown no-subscriber and receiver-only windows cannot downgrade', async () => {
  const f = await fixture()
  for (const patch of [{ visible: false }, { source: 'static' as const }, { source: 'unknown' as const }, { subscribers: 0 },
    { signals: window(1000, f.port.generation()).signals.map(signal => ({ ...signal, bottleneck: 'receiver-downlink-decode' as const, receiverId: 'synthetic' })) }]) {
    f.runtime.reset()
    await f.runtime.step(window(1000, f.port.generation(), patch), 1000)
    await f.runtime.step(window(2000, f.port.generation(), patch), 2000)
  }
  expect(f.port.capture).not.toHaveBeenCalled()
})
it('manual intent, stopped scope and old publication reject stale policy state', async () => {
  const f = await fixture(), generation = f.port.generation()
  await f.runtime.step(window(1000, generation), 1000)
  await f.adapter.update('P720_30')
  await f.runtime.step(window(2000, generation), 2000)
  expect(f.port.capture).toHaveBeenCalledTimes(1)
  expect(f.runtime.state?.ceilingProfile).toBe('P720_30')
  await f.adapter.stop()
  expect(await f.runtime.step(window(3000, generation), 3000)).toMatchObject({ applied: false })
})
