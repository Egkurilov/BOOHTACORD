import type { LocalVideoTrack, RemoteTrack } from 'livekit-client'

type Direction = 'outbound' | 'inbound'
type SafeLayer = {
  rid: string
  codec: string | null
  active: boolean | null
  frameWidth: number | null
  frameHeight: number | null
  frames: number | null
  framesEncoded: number | null
  framesDecoded: number | null
  framesDropped: number | null
  bytes: number | null
  packets: number | null
  packetsLost: number | null
  jitter: number | null
  targetBitrate: number | null
  totalEncodeTime: number | null
  totalDecodeTime: number | null
  framesPerSecond: number | null
  sourceFramesPerSecond: number | null
  freezeCount: number | null
  freezeDuration: number | null
  qualityLimitationReason: string | null
}

function numberOrNull(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null
}

function safeCandidateType(value: unknown) {
  return ['host', 'srflx', 'prflx', 'relay'].includes(String(value)) ? String(value) : null
}

export function sanitizeTrackStats(report: RTCStatsReport | undefined, direction: Direction) {
  const rows: any[] = []
  report?.forEach(row => rows.push(row))
  const codecs = new Map<string, string>(rows.filter(row => row.type === 'codec' && typeof row.id === 'string')
    .map(row => [row.id, typeof row.mimeType === 'string' && /^video\/[a-z0-9._-]{1,32}$/i.test(row.mimeType) ? row.mimeType : '']))
  const pair = rows.find(row => row.type === 'candidate-pair' && (row.selected === true || (row.nominated === true && row.state === 'succeeded')))
  const local = rows.find(row => row.type === 'local-candidate' && row.id === pair?.localCandidateId)
  const remote = rows.find(row => row.type === 'remote-candidate' && row.id === pair?.remoteCandidateId)
  const candidateProtocol = ['udp', 'tcp'].includes(String(local?.protocol).toLowerCase()) ? String(local.protocol).toLowerCase() : null
  const layers = rows.filter(row => row.type === `${direction}-rtp` && (row.kind === 'video' || row.mediaType === 'video')).map((row): SafeLayer => {
    const encoded = direction === 'outbound' ? numberOrNull(row.framesEncoded) : null
    const decoded = direction === 'inbound' ? numberOrNull(row.framesDecoded) : null
    const frames = encoded ?? decoded
    const source = rows.find(candidate => candidate.type === 'media-source' && candidate.id === row.mediaSourceId)
    const reason = ['none', 'cpu', 'bandwidth', 'other'].includes(String(row.qualityLimitationReason)) ? String(row.qualityLimitationReason) : null
    const codec = typeof row.codecId === 'string' ? codecs.get(row.codecId) || null : null
    return {
      rid: typeof row.rid === 'string' && /^[a-z0-9_-]{1,8}$/i.test(row.rid) ? row.rid : 'single',
      codec, active: frames === null ? null : frames > 0,
      frameWidth: numberOrNull(row.frameWidth), frameHeight: numberOrNull(row.frameHeight), frames,
      framesEncoded: encoded, framesDecoded: decoded, framesDropped: numberOrNull(row.framesDropped),
      bytes: numberOrNull(direction === 'outbound' ? row.bytesSent : row.bytesReceived),
      packets: numberOrNull(direction === 'outbound' ? row.packetsSent : row.packetsReceived),
      packetsLost: numberOrNull(row.packetsLost), jitter: numberOrNull(row.jitter), targetBitrate: numberOrNull(row.targetBitrate),
      totalEncodeTime: numberOrNull(row.totalEncodeTime), totalDecodeTime: numberOrNull(row.totalDecodeTime),
      framesPerSecond: numberOrNull(row.framesPerSecond), sourceFramesPerSecond: numberOrNull(source?.framesPerSecond),
      freezeCount: numberOrNull(row.freezeCount), freezeDuration: numberOrNull(row.totalFreezesDuration),
      qualityLimitationReason: reason,
    }
  })
  return {
    layers, candidateProtocol, localCandidateType: safeCandidateType(local?.candidateType), remoteCandidateType: safeCandidateType(remote?.candidateType),
    currentRoundTripTime: numberOrNull(pair?.currentRoundTripTime),
    availableOutgoingBitrate: numberOrNull(pair?.availableOutgoingBitrate),
    availableIncomingBitrate: numberOrNull(pair?.availableIncomingBitrate),
  }
}

export async function sampleSender(track: LocalVideoTrack | null) {
  return sanitizeTrackStats(await track?.getRTCStatsReport(), 'outbound')
}

export async function sampleReceiver(track: RemoteTrack | null) {
  return sanitizeTrackStats(await track?.getRTCStatsReport(), 'inbound')
}

export async function collectSamples<T>(sample: () => Promise<T>, durationMs: number, intervalMs: number) {
  if (durationMs < intervalMs || durationMs > 180_000 || intervalMs < 250) throw new Error('invalid bounded sample window')
  const samples = [await sample()]
  const deadline = performance.now() + durationMs
  while (performance.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, intervalMs))
    samples.push(await sample())
  }
  return samples
}
