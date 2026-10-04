import { audioCodec } from './codec'
import { statNumber, type AudioDirection, type AudioSample, type RawAudioStat } from './model'
type Previous = { at: number; report: RawAudioStat }
export class AudioStatsReader {
  private previous = new Map<string, Previous>()
  retain(scopes: Set<string>): void {
    for (const key of this.previous.keys()) if (!scopes.has(key.split('\n')[0]!)) this.previous.delete(key)
  }
  read(scope: string, direction: AudioDirection, reports: RawAudioStat[], at: number): AudioSample[] {
    const type = direction === 'sender' ? 'outbound-rtp' : 'inbound-rtp'
    const activeKeys = new Set(reports.filter((rtp) => rtp.type === type).map((rtp) => scope + '\n' + String(rtp.id)))
    for (const key of this.previous.keys()) if (key.startsWith(scope + '\n') && !activeKeys.has(key)) this.previous.delete(key)
    return reports.filter((rtp) => rtp.type === type && (rtp.kind ?? rtp.mediaType ?? 'audio') === 'audio' && !rtp.isRemote).map((rtp) => {
      const key = scope + '\n' + String(rtp.id)
      const old = this.previous.get(key)
      const dt = old ? at - old.at : 0
      const fresh = !old || rtp.timestamp !== old.report.timestamp || rtp.timestamp === undefined
      const valid = fresh && dt > 0 && dt <= 15000
      const delta = (field: string): number | null => {
        const current = statNumber(rtp[field]), previous = statNumber(old?.report[field])
        return valid && current !== null && previous !== null && current >= previous ? current - previous : null
      }
      const bytes = delta(direction === 'sender' ? 'bytesSent' : 'bytesReceived')
      const packets = delta(direction === 'sender' ? 'packetsSent' : 'packetsReceived')
      const lost = delta('packetsLost')
      if (fresh) this.previous.set(key, { at, report: { ...rtp } })
      const jitter = statNumber(rtp.jitter)
      const level = statNumber(rtp.audioLevel) ?? statNumber(reports.find((entry) => entry.id === rtp.mediaSourceId)?.audioLevel)
      return { direction, ...audioCodec(rtp, reports),
        bitrateBps: bytes === null ? null : bytes * 8000 / dt, packets,
        intervalMs: valid ? dt : null,
        jitterMs: jitter === null ? null : jitter * 1000,
        lossPercent: packets !== null && lost !== null && packets + lost > 0 ? lost * 100 / (packets + lost) : null,
        concealedSamples: delta('concealedSamples'), concealmentEvents: delta('concealmentEvents'),
        audioLevel: level === null || level > 1 ? null : level }
    })
  }
}
