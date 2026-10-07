import { expect, it } from 'vitest'
import { receiverSnapshotFromReport } from './screen_receiver_reader'
const report = (rows: Record<string, unknown>[]) => new Map(rows.map((row, index) => [String(index), row])) as unknown as RTCStatsReport
it('reads actual primary video counters and ignores audio and RTX rows', () => {
  const snapshot = receiverSnapshotFromReport(report([
    { id: 'audio', type: 'inbound-rtp', kind: 'audio', framesDecoded: 9 },
    { id: 'video', type: 'inbound-rtp', kind: 'video', ssrc: 10, timestamp: 2000, framesDecoded: 30, totalDecodeTime: 0.06, freezeCount: 2 },
    { id: 'rtx', type: 'inbound-rtp', kind: 'video', bytesReceived: 20 },
  ]))
  expect(snapshot).toMatchObject({ streamId: 'video', ssrc: 10, framesDecoded: 30, totalDecodeTime: 0.06, freezeCount: 2 })
  expect(snapshot?.jitterBufferEmittedCount).toBeUndefined()
})
it('returns unavailable for ambiguous or unsupported video counters', () => {
  expect(receiverSnapshotFromReport(report([{ type: 'inbound-rtp', kind: 'video' }]))).toBeUndefined()
  expect(receiverSnapshotFromReport(report([{ type: 'inbound-rtp', kind: 'video', framesDecoded: 10 }, { type: 'inbound-rtp', kind: 'video', framesDecoded: 20 }]))).toBeUndefined()
})
