import { vi } from 'vitest'
import { ScreenPublisherAdapter, type ScreenPublisherPort } from './adapter'

export function setup() {
  type FakeTrack = { id: string }
  const owner = {}, room = {}, track: FakeTrack = { id: 'capture' }, calls: string[] = []
  let generation = 0, published: FakeTrack | undefined
  const listeners = new Set<(track: FakeTrack) => void>()
  const port: ScreenPublisherPort<FakeTrack> & {
    onPublished(listener: (track: FakeTrack) => void): () => void
    trackPublished(track: FakeTrack): void
  } = {
    generation: () => generation, isLive: () => true,
    start: vi.fn(async () => { calls.push('start'); published = track; generation++; return track }),
    currentTrack: vi.fn(() => published),
    capture: vi.fn(async (_track, profile) => { calls.push(`capture:${profile}`) }),
    unpublish: vi.fn(async () => { calls.push('unpublish'); published = undefined; generation++ }),
    publish: vi.fn(async (_track, profile) => { calls.push(`publish:${profile}`); published = track; generation++ }),
    stop: vi.fn(async () => { calls.push('stop'); published = undefined; generation++ }),
    diagnostics: vi.fn(async () => ({ audioTrack: 'PRESENT' as const, connectionQuality: 'UNKNOWN' as const, measured: null, source: 'ACTIVE' as const })),
    onPublished: listener => { listeners.add(listener); return () => listeners.delete(listener) },
    trackPublished: publishedTrack => { generation++; listeners.forEach(listener => listener(publishedTrack)) },
  }
  const current = vi.fn(() => ({ owner, room, port }))
  return { adapter: new ScreenPublisherAdapter(current), port, current, calls, track,
    setPublished: (value?: FakeTrack) => { published = value }, republish: () => { published = track; port.trackPublished(track) } }
}
