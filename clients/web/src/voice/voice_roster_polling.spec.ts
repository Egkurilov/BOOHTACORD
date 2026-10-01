import { describe, expect, it, vi } from 'vitest'

import { createVoiceRosterPolling } from './voice_roster_polling'

describe('voice roster polling lifecycle', () => {
  it('does not expose an old account snapshot after stop and new start', async () => {
    let resolveOld!: (value: { channelId: string; participants: [] }[]) => void
    const load = vi.fn()
      .mockImplementationOnce(() => new Promise(resolve => { resolveOld = resolve }))
      .mockResolvedValueOnce([{ channelId: 'voice-new', participants: [] }])
    const roster = createVoiceRosterPolling(load, 60_000)
    roster.start()
    roster.stop()
    roster.start()
    await roster.refresh()
    resolveOld([{ channelId: 'voice-old', participants: [] }])
    await Promise.resolve()

    expect(roster.channels.value).toEqual([{ channelId: 'voice-new', participants: [] }])
    roster.stop()
  })

  it('marks LiveKit snapshot failure as unavailable rather than an empty room', async () => {
    const roster = createVoiceRosterPolling(vi.fn().mockRejectedValue(new Error('503')), 60_000)
    roster.start()
    await roster.refresh()
    expect(roster.channels.value).toBeNull()
    expect(roster.error.value).toContain('503')
    roster.stop()
  })
})
