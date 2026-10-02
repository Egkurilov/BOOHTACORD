import { expect, it } from 'vitest'
import { applyScreenProfile } from './apply'
import { inspectScreenProfile } from './inspect'
import { profileTrack } from './fixture'

function report(rows: Record<string, unknown>[]): RTCStatsReport {
  return new Map(rows.map(row => [row.id, row])) as unknown as RTCStatsReport
}

it('detects oversized advancing output while ignoring stale and disabled layers', async () => {
  const f = profileTrack(), frames = new Map<string, number>()
  await applyScreenProfile(f.track, 'P1080_60')
  f.sender.getStats.mockResolvedValue(report([
    { id: 'v', rid: 'h', type: 'outbound-rtp', kind: 'video', frameWidth: 2560, frameHeight: 1440, framesEncoded: 20, framesPerSecond: 40 },
    { id: 'l', rid: 'l', type: 'outbound-rtp', kind: 'video', frameWidth: 4096, frameHeight: 2160, framesEncoded: 40, framesPerSecond: 60 },
  ]))
  expect(await inspectScreenProfile(f.track, 'P1080_60', frames)).toMatchObject({ status: 'drift', reason: 'resolution' })
  expect(await inspectScreenProfile(f.track, 'P1080_60', frames)).toMatchObject({ status: 'checking', reason: 'unavailable' })
  f.sender.getStats.mockResolvedValue(report([
    { id: 'v', rid: 'h', type: 'outbound-rtp', kind: 'video', frameWidth: 1920, frameHeight: 1080, framesEncoded: 21, framesPerSecond: 60 },
    { id: 'l', rid: 'l', type: 'outbound-rtp', kind: 'video', frameWidth: 4096, frameHeight: 2160, framesEncoded: 41, framesPerSecond: 60 },
  ]))
  expect(await inspectScreenProfile(f.track, 'P1080_60', frames)).toMatchObject({ status: 'matched' })
})

it('reports capture drift independently of encoded dimensions', async () => {
  const f = profileTrack()
  await applyScreenProfile(f.track, 'P1080_60')
  f.setSettings({ width: 2560, height: 1440, frameRate: 60 })
  expect(await inspectScreenProfile(f.track, 'P1080_60', new Map())).toMatchObject({ status: 'drift', reason: 'capture', captureWidth: 2560 })
})

it('does not manufacture output measurements when getStats is empty', async () => {
  const f = profileTrack()
  await applyScreenProfile(f.track, 'P1080_60')
  f.sender.getStats.mockResolvedValue(report([]))
  expect(await inspectScreenProfile(f.track, 'P1080_60', new Map())).toMatchObject({ status: 'checking', reason: 'unavailable' })
})
