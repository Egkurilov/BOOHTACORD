import type { ScreenViewerCard, ScreenViewerTrack } from './screen_viewer_types'
import type { ScreenReceiverSnapshot } from './screen_receiver_diagnostics'
import { screenSenderStatsSampler } from './screen_stats_sampler'

type Reader = NonNullable<ScreenViewerCard['readReceiverStats']>

export function receiverSnapshotFromReport(report: RTCStatsReport): ScreenReceiverSnapshot | undefined {
  let selected: Record<string, unknown> | undefined
  let matches = 0
  report.forEach(stat => {
    const row = stat as unknown as Record<string, unknown>
    if (row.type === 'inbound-rtp' && (row.kind ?? row.mediaType) === 'video' && typeof row.framesDecoded === 'number' && Number.isFinite(row.framesDecoded)) { selected = row; matches += 1 }
  })
  if (!selected || matches !== 1) return undefined
  const row = selected
  const number = (key: string) => typeof row[key] === 'number' && Number.isFinite(row[key]) ? row[key] as number : undefined
  return { timestamp: number('timestamp') ?? NaN, streamId: typeof row.id === 'string' ? row.id : undefined, ssrc: number('ssrc'),
    bytesReceived: number('bytesReceived'), framesDecoded: number('framesDecoded') ?? NaN,
    framesDropped: number('framesDropped') ?? NaN, packetsReceived: number('packetsReceived'), packetsLost: number('packetsLost'),
    jitter: number('jitter'), totalDecodeTime: number('totalDecodeTime'), jitterBufferDelay: number('jitterBufferDelay'),
    jitterBufferEmittedCount: number('jitterBufferEmittedCount'), nackCount: number('nackCount'), pliCount: number('pliCount'),
    firCount: number('firCount'), freezeCount: number('freezeCount'), totalFreezesDuration: number('totalFreezesDuration') }
}

export function createScreenReceiverReader(): (track: ScreenViewerTrack) => Reader {
  const readers = new WeakMap<ScreenViewerTrack, Reader>()
  return (track) => {
    let reader = readers.get(track)
    if (!reader) {
      reader = async () => track.receiver ? receiverSnapshotFromReport(await screenSenderStatsSampler.read(track.receiver)) : track.getReceiverStats!()
      readers.set(track, reader)
    }
    return reader
  }
}
