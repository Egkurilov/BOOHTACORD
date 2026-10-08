import { expect, it, vi } from 'vitest'
import { ScreenAdaptationBinding } from './binding'
import { ScreenAdaptationRuntime } from './runtime'
import { calibration, fixture, window } from './fixture'

it('failed writer rolls back effective profile without consuming ceiling or transition budget', async () => {
  const f = await fixture(), generation = f.port.generation()
  await f.runtime.step(window(1000, generation), 1000)
  vi.mocked(f.port.capture).mockRejectedValueOnce(new Error('synthetic constraint failure'))
  expect(await f.runtime.step(window(2000, generation), 2000)).toMatchObject({ reason: 'writer-failed', applied: false })
  expect(f.adapter.active?.profile).toBe('P1080_60')
  expect(f.runtime.state?.currentProfile).toBe('P1080_60')
  expect(f.runtime.state?.ceilingProfile).toBe('P1080_60')
  expect(f.runtime.state?.transitions).toBe(0)
})
it('stale diagnostic reads and failed classified input cannot mutate a new owner', async () => {
  const f = await fixture()
  const binding = new ScreenAdaptationBinding(f.adapter, { enabled: true, calibration, now: () => 2000,
    readWindow: () => { throw new Error('synthetic diagnostic provider outage') } })
  expect((await binding.read(() => f.port.diagnostics())).adaptationReason).toBe('input-unavailable')
  let release!: () => void
  const pending = new Promise<void>(done => { release = done })
  const reading = binding.read(async () => { await pending; return f.port.diagnostics() })
  f.current.mockReturnValue({ ...f.current(), owner: {} })
  release()
  expect((await reading).adaptationReason).toBe('stale-owner')
  expect(f.port.capture).not.toHaveBeenCalled()
})
it('explicit reset invalidates pending diagnostic work and options cannot be remotely toggled', async () => {
  const f = await fixture(), options = { enabled: false, calibration }
  const runtime = new ScreenAdaptationRuntime(f.adapter, options)
  options.enabled = true
  expect(runtime.enabled).toBe(false)
  const ticket = f.runtime.capture()!
  f.runtime.reset()
  expect(f.runtime.current(ticket)).toBe(false)
  expect(await f.runtime.step(window(1000, ticket.generation), 1000, ticket)).toMatchObject({ applied: false })
})
