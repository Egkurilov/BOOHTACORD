import { afterEach, expect, it, vi } from 'vitest'
import { createVoiceRosterRealtime, type VoiceRosterEvents } from '../voice_roster_realtime'

afterEach(() => vi.useRealTimers())

function fixture() {
  const sources: VoiceRosterEvents[] = []
  const roster = createVoiceRosterRealtime(() => {
    const source: VoiceRosterEvents = {
      onmessage: null, onerror: null, addEventListener: vi.fn(), close: vi.fn(),
    }
    sources.push(source)
    return source
  })
  roster.start()
  return { roster, sources }
}

it('expires data across manual reconnect while retaining last successful age', () => {
  vi.useFakeTimers()
  vi.setSystemTime(100_000)
  const { roster, sources } = fixture()
  sources[0].onmessage?.({ data: '{"channels":[{"channel_id":"room","participants":[]}]}' })
  sources[0].onerror?.()
  vi.advanceTimersByTime(9000)
  roster.reconnect()
  sources[1].onerror?.()
  vi.advanceTimersByTime(1000)
  expect(roster.channels.value).toBeNull()
  expect(roster.status.value).toBe('unavailable')
  expect(roster.lastUpdatedAt.value).toBe(100_000)
  roster.stop()
  expect(roster.lastUpdatedAt.value).toBeNull()
})

it('a successful replacement cancels the old expiry deadline', () => {
  vi.useFakeTimers()
  const { roster, sources } = fixture()
  sources[0].onmessage?.({ data: '{"channels":[]}' })
  sources[0].onerror?.()
  roster.reconnect()
  sources[1].onmessage?.({ data: '{"channels":[]}' })
  vi.advanceTimersByTime(20_000)
  expect(roster.status.value).toBe('fresh_empty')
  expect(roster.channels.value).toEqual([])
  roster.stop()
})
