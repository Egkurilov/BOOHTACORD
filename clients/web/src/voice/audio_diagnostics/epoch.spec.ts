import { expect, it } from 'vitest'
import { AudioStatsReader } from './stats'
import { statNumber } from './model'
const reports = (bytes: number, packets: number, timestamp: number, extra = {}) => [
  { id: 'rtp', type: 'inbound-rtp', kind: 'audio', ssrc: 1, codecId: 'opus',
    bytesReceived: bytes, packetsReceived: packets, packetsLost: 1,
    concealedSamples: 480, concealmentEvents: 1, timestamp, ...extra },
]
it.each(['ssrc', 'codecId', 'mediaSourceId', 'mid', 'transportId'])('rebaselines %s changes even with reused report id', (field) => {
  const reader = new AudioStatsReader()
  reader.read('mic', 'receiver', reports(1000, 10, 1), 0)
  const extra = { [field]: field === 'ssrc' ? 2 : 'new-opus' }
  const replaced = reader.read('mic', 'receiver', reports(17000, 30, 2, extra), 2000)[0]!
  expect(replaced.bitrateBps).toBeNull(); expect(replaced.packets).toBeNull()
  expect(replaced.intervalMs).toBeNull(); expect(replaced.concealedSamples).toBeNull()
  expect(reader.read('mic', 'receiver', reports(33000, 50, 3, extra), 4000)[0]!.bitrateBps).toBe(64000)
})
it.each(['bytesReceived', 'packetsReceived'])('%s rollback invalidates the entire interval, then recovers', (field) => {
  const reader = new AudioStatsReader()
  reader.read('mic', 'receiver', reports(1000, 10, 1), 0)
  const reset = reader.read('mic', 'receiver', reports(1500, 20, 2, { [field]: 1 }), 2000)[0]!
  for (const key of ['intervalMs', 'bitrateBps', 'packets', 'lossPercent', 'concealedSamples', 'concealmentEvents'] as const) expect(reset[key]).toBeNull()
  expect(reader.read('mic', 'receiver', reports(field === 'bytesReceived' ? 16001 : 17500, 40, 3), 4000)[0]!.bitrateBps).toBe(64000)
})
it('stale timestamps cannot rewind a valid counter baseline', () => {
  const reader = new AudioStatsReader()
  reader.read('mic', 'receiver', reports(100, 10, 10), 0)
  expect(reader.read('mic', 'receiver', reports(500, 20, 9), 2000)[0]!.bitrateBps).toBeNull()
  expect(reader.read('mic', 'receiver', reports(1100, 30, 11), 4000)[0]!.bitrateBps).toBe(2000)
})
it('whitespace cannot be interpreted as measured zero', () => {
  expect(statNumber('   ')).toBeNull()
})
