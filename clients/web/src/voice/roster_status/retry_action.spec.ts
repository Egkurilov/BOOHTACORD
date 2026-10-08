import { describe, expect, it, vi } from 'vitest'

import { retryVoiceRoster } from './retry_action'
import { createVoiceRosterRealtime, type VoiceRosterEvents } from '../voice_roster_realtime'

describe('voice roster manual retry', () => {
  it('replaces the active stream and clears the action when stopped', () => {
    const sources: VoiceRosterEvents[] = []
    const factory = vi.fn(() => {
      const source: VoiceRosterEvents = { onmessage: null, onerror: null, addEventListener: vi.fn(), close: vi.fn() }
      sources.push(source)
      return source
    })
    const roster = createVoiceRosterRealtime(factory)
    roster.start()

    expect(retryVoiceRoster()).toBe(true)
    expect(factory).toHaveBeenCalledTimes(2)
    expect(sources[0].close).toHaveBeenCalledOnce()
    roster.stop()
    expect(retryVoiceRoster()).toBe(false)
  })
})
