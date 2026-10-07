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

  it('times out a stuck stats request and permits the next bounded sample', async () => {
    vi.useFakeTimers()
    const sampler = new ScreenSenderStatsSampler()
    const report = new Map() as unknown as RTCStatsReport
    const sender = { getStats: vi.fn()
      .mockImplementationOnce(() => new Promise<RTCStatsReport>(() => {}))
      .mockResolvedValue(report) }
    const stuck = sampler.read(sender, 0)
    const rejected = expect(stuck).rejects.toThrow('screen stats timed out')
    await vi.advanceTimersByTimeAsync(2000)
    await rejected
    await expect(sampler.read(sender, 2000)).resolves.toBe(report)
  })
})
