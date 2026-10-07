import type { LocalVideoTrack } from 'livekit-client'

export async function sampleSender(track: LocalVideoTrack | null) {
  const report = await track?.getRTCStatsReport()
  if (!report) return []
  const rows: any[] = []
  report.forEach(row => rows.push(row))
  const codecs = new Map(rows.filter(row => row.type === 'codec').map(row => [row.id, row.mimeType]))
  return rows.filter(row => row.type === 'outbound-rtp' && (row.kind === 'video' || row.mediaType === 'video'))
    .map(row => ({
      rid: typeof row.rid === 'string' ? row.rid : 'single',
      codec: codecs.get(row.codecId) ?? null,
      frameWidth: row.frameWidth ?? null,
      frameHeight: row.frameHeight ?? null,
      framesEncoded: row.framesEncoded ?? null,
      bytesSent: row.bytesSent ?? null,
      retransmittedBytesSent: row.retransmittedBytesSent ?? null,
      totalEncodeTime: row.totalEncodeTime ?? null,
      framesPerSecond: row.framesPerSecond ?? null,
      qualityLimitationReason: row.qualityLimitationReason ?? null,
    }))
}

export async function collectSamples<T>(sample: () => Promise<T>, durationMs: number, intervalMs: number) {
  if (durationMs < intervalMs || durationMs > 60_000 || intervalMs < 250) throw new Error('invalid bounded sample window')
  const samples = [await sample()]
  const deadline = performance.now() + durationMs
  while (performance.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, intervalMs))
    samples.push(await sample())
  }
  return samples
}
