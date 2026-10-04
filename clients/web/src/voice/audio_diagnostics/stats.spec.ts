import { expect, it } from 'vitest'
import { AudioStatsReader } from './stats'
const report = (bytes: number, packets: number, lost = 0, timestamp = bytes) => [
  { id: 'codec', type: 'codec', mimeType: 'audio/opus', clockRate: 48000, channels: 2, sdpFmtpLine: 'useinbandfec=1;usedtx=1;stereo=0' },
  { id: 'rtp', type: 'inbound-rtp', kind: 'audio', codecId: 'codec', bytesReceived: bytes, packetsReceived: packets, packetsLost: lost, jitter: 0.01, concealedSamples: lost * 480, concealmentEvents: lost, timestamp },
]
it('uses interval counters, not lifetime averages or assumed capture channels', () => {
  const reader = new AudioStatsReader()
  expect(reader.read('track', 'receiver', report(100, 10), 0)[0]!.bitrateBps).toBeNull()
  const sample = reader.read('track', 'receiver', report(16100, 109, 1), 2000)[0]!
  expect(sample.bitrateBps).toBe(64000)
  expect(sample.lossPercent).toBe(1)
  expect(sample.jitterMs).toBe(10)
  expect(sample.concealedSamples).toBe(480)
  expect(sample.codecChannels).toBe(2)
  expect(sample.stereo).toBe(false)
  expect(sample.fec).toBe(true)
})
it('resets on rollback, track replacement, missing and duplicate reports', () => {
  const reader = new AudioStatsReader()
  reader.read('track', 'receiver', report(100, 10), 0)
  expect(reader.read('track', 'receiver', report(100, 10), 2000)[0]!.bitrateBps).toBeNull()
  expect(reader.read('new-track', 'receiver', report(500, 30), 4000)[0]!.bitrateBps).toBeNull()
  expect(reader.read('track', 'receiver', report(50, 5), 4000)[0]!.bitrateBps).toBeNull()
  reader.retain(new Set())
  expect(reader.read('track', 'receiver', report(500, 30), 6000)[0]!.bitrateBps).toBeNull()
  expect(reader.read('video', 'receiver', [{ type: 'inbound-rtp', kind: 'video' }], 6000)).toEqual([])
})
it('resolves RED to the actual Opus payload and leaves unreported flags unknown', () => {
  const reader = new AudioStatsReader()
  const reports = report(100, 1)
  reports.push({ id: 'red', type: 'codec', mimeType: 'audio/red', clockRate: 48000, channels: 2, sdpFmtpLine: '111/111' } as never)
  Object.assign(reports[0]!, { payloadType: 111, sdpFmtpLine: '' })
  Object.assign(reports[1]!, { codecId: 'red' })
  const sample = reader.read('track', 'receiver', reports, 0)[0]!
  expect(sample.codec).toBe('opus'); expect(sample.red).toBe(true)
  expect(sample.dtx).toBeNull(); expect(sample.fec).toBeNull()
})
