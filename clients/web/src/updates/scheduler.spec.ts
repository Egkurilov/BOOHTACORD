import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { UpdateScheduler } from './scheduler'

describe('update scheduler', () => {
  beforeEach(() => vi.useFakeTimers())
  afterEach(() => vi.useRealTimers())

  it('never overlaps checks and stops after disposal', async () => {
    let finish!: () => void
    const check = vi.fn(() => new Promise<void>((resolve) => { finish = resolve }))
    const scheduler = new UpdateScheduler(check, () => 0)
    scheduler.start()
    await vi.runOnlyPendingTimersAsync()
    expect(check).toHaveBeenCalledTimes(1)
    scheduler.manual(); expect(check).toHaveBeenCalledTimes(1)
    finish(); await Promise.resolve(); scheduler.dispose()
    await vi.runAllTimersAsync()
    expect(check).toHaveBeenCalledTimes(1)
  })
})
