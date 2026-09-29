import { afterEach, describe, expect, it, vi } from 'vitest'

import { monitorVoiceConnectionStats } from './voice_connection_stats_polling'

describe('voice connection stats polling', () => {
  afterEach(() => vi.useRealTimers())

  it('samples immediately, refreshes while active, and stops on dispose', async () => {
    vi.useFakeTimers()
    const read = vi.fn().mockResolvedValue({ quality: 'GOOD', pingMs: 38 })
    const publish = vi.fn()
    const stop = monitorVoiceConnectionStats(read, publish)
    await vi.advanceTimersByTimeAsync(0)

    expect(publish).toHaveBeenCalledWith({ quality: 'GOOD', pingMs: 38 })
    await vi.advanceTimersByTimeAsync(4000)
    expect(read).toHaveBeenCalledTimes(3)
    stop()
    await vi.advanceTimersByTimeAsync(6000)
    expect(read).toHaveBeenCalledTimes(3)
  })

  it('does not publish a late sample after reconnect or leave stops polling', async () => {
    vi.useFakeTimers()
    let resolveSample: ((stats: { quality: 'GOOD'; pingMs: number }) => void) | undefined
    const read = vi.fn(() => new Promise<{ quality: 'GOOD'; pingMs: number }>((resolve) => { resolveSample = resolve }))
    const publish = vi.fn()
    const stop = monitorVoiceConnectionStats(read, publish)
    stop()
    resolveSample?.({ quality: 'GOOD', pingMs: 38 })
    await vi.advanceTimersByTimeAsync(0)

    expect(publish).not.toHaveBeenCalled()
    expect(read).toHaveBeenCalledOnce()
  })

  it('reports read failures without leaking a rejected polling promise', async () => {
    vi.useFakeTimers()
    const read = vi.fn().mockRejectedValue(new Error('stats unavailable'))
    const publish = vi.fn()
    const failed = vi.fn()
    const stop = monitorVoiceConnectionStats(read, publish, failed)
    await vi.advanceTimersByTimeAsync(0)

    expect(publish).not.toHaveBeenCalled()
    expect(failed).toHaveBeenCalledOnce()
    stop()
  })
})
