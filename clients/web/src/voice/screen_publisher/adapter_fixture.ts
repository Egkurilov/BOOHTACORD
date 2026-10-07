import { vi } from 'vitest'
import { ScreenPublisherAdapter, type ScreenPublisherPort } from './adapter'

export function setup() {
  const owner = {}, room = {}, track = { id: 'capture' }, calls: string[] = []
  let generation = 0, published: typeof track | undefined
  const port: ScreenPublisherPort<typeof track> = {
    generation: () => generation, isLive: () => true,
    start: vi.fn(async () => { calls.push('start'); published = track; generation++; return track }),
    currentTrack: vi.fn(() => published),
    capture: vi.fn(async (_track, profile) => { calls.push(`capture:${profile}`) }),
    unpublish: vi.fn(async () => { calls.push('unpublish'); published = undefined; generation++ }),
    publish: vi.fn(async (_track, profile) => { calls.push(`publish:${profile}`); published = track; generation++ }),
    stop: vi.fn(async () => { calls.push('stop'); published = undefined; generation++ }),
    diagnostics: vi.fn(async () => ({ audioTrack: 'PRESENT' as const, connectionQuality: 'UNKNOWN' as const, measured: null, source: 'ACTIVE' as const })),
  }
  const current = vi.fn(() => ({ owner, room, port }))
  return { adapter: new ScreenPublisherAdapter(current), port, current, calls, track, setPublished: (value?: typeof track) => { published = value } }
}
