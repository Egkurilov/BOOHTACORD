import { afterEach, expect, it, vi } from 'vitest'
import type { LocalParticipant, LocalVideoTrack } from 'livekit-client'
import { bindLiveKitScreenPublisher } from '../screen_publisher/livekit_port'

afterEach(() => vi.unstubAllEnvs())
it('room publication keeps its original flags across start, update and repair', async () => {
  vi.stubEnv('VITE_SCREEN_SHARE_BOUNDED_SIMULCAST', 'true')
  const track = { mediaStreamTrack: { readyState: 'live', getSettings: () => ({ width: 1920, height: 1080 }), applyConstraints: vi.fn() } } as unknown as LocalVideoTrack
  const participant = {
    getTrackPublication: () => ({ videoTrack: track }),
    setScreenShareEnabled: vi.fn<LocalParticipant['setScreenShareEnabled']>(async () => ({ videoTrack: track }) as never),
    publishTrack: vi.fn<LocalParticipant['publishTrack']>(async () => undefined as never),
    unpublishTrack: vi.fn(async () => undefined),
  }
  const port = bindLiveKitScreenPublisher(participant as unknown as LocalParticipant,
    vi.fn(), vi.fn(), async (_profile, action) => { await action(); return true })
  vi.stubEnv('VITE_SCREEN_SHARE_BOUNDED_SIMULCAST', 'false')
  await port.start('P1080_30'); await port.publish(track, 'P720_15')
  await port.repair!(track, 'P720_15', () => true)
  expect(participant.setScreenShareEnabled.mock.calls[0]![2]).toMatchObject({ simulcast: true })
  expect(participant.publishTrack.mock.calls[0]![1]).toMatchObject({ simulcast: true })
  expect(participant.publishTrack.mock.calls[1]![1]).toMatchObject({ simulcast: true })
  const next = bindLiveKitScreenPublisher(participant as unknown as LocalParticipant, vi.fn(), vi.fn(), vi.fn())
  await next.start('P1080_30')
  expect(participant.setScreenShareEnabled.mock.calls[1]![2]).toMatchObject({ simulcast: false })
})
