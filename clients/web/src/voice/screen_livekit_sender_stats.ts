import type { ScreenSenderStats } from './screen_diagnostics'
import type { RawScreenLayerStats } from './screen_sender_layers'
import { screenSenderStatsSampler } from './screen_stats_sampler'
import { sourceCountersFromReport } from './viewer_diagnosis/capture'

export interface LiveKitScreenVideoTrack {
  sender?: Pick<RTCRtpSender, 'getStats'>
  currentBitrate?: number
  getSenderStats(): Promise<ScreenSenderStats[]>
  getSourceTrackSettings(): MediaTrackSettings
  mediaStreamTrack: { readyState: string }
}

function relatedRemoteInbound(report: RTCStatsReport): Map<string, Record<string, unknown>> {
  const related = new Map<string, Record<string, unknown>>()
  report.forEach(stat => {
    const row = stat as unknown as Record<string, unknown>
    if (row.type === 'remote-inbound-rtp' && typeof row.localId === 'string') related.set(row.localId, row)
  })
  return related
}

function number(row: Record<string, unknown>, key: string): number | undefined {
  const field = row[key]
  return typeof field === 'number' && Number.isFinite(field) ? field : undefined
}

function text(row: Record<string, unknown>, key: string): string | undefined {
  const field = row[key]
  return typeof field === 'string' && field.length > 0 ? field : undefined
}

export async function readLiveKitScreenSenderStats(video: LiveKitScreenVideoTrack): Promise<{
  rows: RawScreenLayerStats[]
  counters: { capturedFrames: number | null; encodedFrames: number | null }
}> {
  if (!video.sender) return { rows: [], counters: { capturedFrames: null, encodedFrames: null } }
  const report = await screenSenderStatsSampler.read(video.sender)
  const remoteInbound = relatedRemoteInbound(report)
  const codecs = new Map<string, string>()
  report.forEach(stat => {
    const row = stat as unknown as Record<string, unknown>
    if (row.type === 'codec' && typeof row.id === 'string' && typeof row.mimeType === 'string') codecs.set(row.id, row.mimeType)
  })
  const rows: RawScreenLayerStats[] = []
  report.forEach(stat => {
    const row = stat as unknown as Record<string, unknown>
    if (row.type !== 'outbound-rtp' || (row.kind ?? row.mediaType) !== 'video') return
    const codecId = text(row, 'codecId')
    const remote = typeof row.id === 'string' ? remoteInbound.get(row.id) : undefined
    rows.push({
      id: text(row, 'id'), timestamp: number(row, 'timestamp') ?? NaN,
      ssrc: number(row, 'ssrc'), rid: text(row, 'rid'), codec: codecId ? codecs.get(codecId) : undefined,
      active: typeof row.active === 'boolean' ? row.active : undefined,
      frameWidth: number(row, 'frameWidth'), frameHeight: number(row, 'frameHeight'),
      framesEncoded: number(row, 'framesEncoded'), bytesSent: number(row, 'bytesSent'),
      retransmittedBytesSent: number(row, 'retransmittedBytesSent'), packetsSent: number(row, 'packetsSent'),
      packetsLost: number(remote ?? {}, 'packetsLost'), roundTripTime: number(remote ?? {}, 'roundTripTime'),
      qualityLimitationReason: text(row, 'qualityLimitationReason'),
      nackCount: number(row, 'nackCount'), pliCount: number(row, 'pliCount'), firCount: number(row, 'firCount'),
      totalEncodeTime: number(row, 'totalEncodeTime'),
    })
  })
  return { rows, counters: sourceCountersFromReport(report) }
}
