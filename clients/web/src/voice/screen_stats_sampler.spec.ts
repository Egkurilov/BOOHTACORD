import { afterEach, describe, expect, it, vi } from 'vitest'

import { ScreenSenderStatsSampler } from './screen_stats_sampler'

afterEach(() => vi.useRealTimers())

describe('bounded sender stats sampler', () => {
  it('shares in-flight and fresh samples and polls at most once per second', async () => {
    const sampler = new ScreenSenderStatsSampler()
    const report = new Map() as unknown as RTCStatsReport
    const sender = { getStats: vi.fn(async () => report) }
    const simultaneous = await Promise.all([sampler.read(sender, 0), sampler.read(sender, 10)])
    expect(simultaneous[0]).toBe(report)
    await sampler.read(sender, 999)
    expect(sender.getStats).toHaveBeenCalledTimes(1)
    await sampler.read(sender, 1000)
    expect(sender.getStats).toHaveBeenCalledTimes(2)
  })

  it('does not retain a sample completed after lifecycle cleanup', async () => {
    const sampler = new ScreenSenderStatsSampler()
    let finish: ((report: RTCStatsReport) => void) | undefined
    let calls = 0
    const report = new Map() as unknown as RTCStatsReport
    const sender = { getStats: vi.fn(() => ++calls === 1
      ? new Promise<RTCStatsReport>(resolve => { finish = resolve })
      : Promise.resolve(report)) }
    const pending = sampler.read(sender, 0)
    await Promise.resolve()
    sampler.clear(sender)
    finish?.(report)
    await pending
    await sampler.read(sender, 1)
    expect(sender.getStats).toHaveBeenCalledTimes(2)
  })

  it('times out callers without issuing concurrent native getStats retries', async () => {
    vi.useFakeTimers()
    const sampler = new ScreenSenderStatsSampler()
    const report = new Map() as unknown as RTCStatsReport
    let finish: ((report: RTCStatsReport) => void) | undefined
    const sender = { getStats: vi.fn()
      .mockImplementationOnce(() => new Promise<RTCStatsReport>(resolve => { finish = resolve }))
      .mockResolvedValue(report) }
    const stuck = sampler.read(sender, 0)
    const rejected = expect(stuck).rejects.toThrow('screen stats timed out')
    await vi.advanceTimersByTimeAsync(2000)
    await rejected
    await expect(sampler.read(sender, 2000)).rejects.toThrow('screen stats timed out')
    expect(sender.getStats).toHaveBeenCalledTimes(1)
    finish?.(report)
    await Promise.resolve(); await Promise.resolve(); await Promise.resolve()
    await expect(sampler.read(sender, 3000)).resolves.toBe(report)
    expect(sender.getStats).toHaveBeenCalledTimes(2)
  })
})


it('keeps lifecycle-cleared native request exclusive until settlement', async () => {
  const sampler = new ScreenSenderStatsSampler()
  let finish: ((report: RTCStatsReport) => void) | undefined
  const report = new Map() as unknown as RTCStatsReport
  const sender = { getStats: vi.fn(() => new Promise<RTCStatsReport>(resolve => { finish = resolve })) }
  const first = sampler.read(sender, 0)
  await Promise.resolve()
  sampler.clear(sender)
  const joined = sampler.read(sender, 500)
  expect(sender.getStats).toHaveBeenCalledTimes(1)
  finish?.(report)
  await Promise.all([first, joined])
})
