import { SpanKind, trace } from '@opentelemetry/api'
import type { AudioSample, VoiceAudioDiagnostics } from './model'
const bucket = (value: number | null, step: number, max: number): string | undefined =>
  value === null || !Number.isFinite(value) || value < 0 ? undefined : String(Math.min(max, Math.floor(value / step) * step))
export function audioTelemetryAttributes(profile: string, sample: AudioSample): Record<string, string> {
  const attrs: Record<string, string> = { 'client.platform': 'web', 'voice.audio.profile': profile, direction: sample.direction }
  const fields = { codec: sample.codec ?? undefined, channels: bucket(sample.codecChannels, 1, 2),
    sample_rate: sample.clockRate === 48000 ? '48000' : undefined,
    bitrate_kbps: bucket(sample.bitrateBps === null ? null : sample.bitrateBps / 1000, 8, 512),
    packets: bucket(sample.packets, 10, 10000), jitter_ms: bucket(sample.jitterMs, 5, 1000),
    loss_percent: bucket(sample.lossPercent, 1, 100),
    concealed_samples: bucket(sample.concealedSamples, 480, 480000), concealment_events: bucket(sample.concealmentEvents, 1, 10000) }
  for (const [key, value] of Object.entries(fields)) if (value !== undefined) attrs[key] = value
  for (const key of ['dtx', 'red', 'fec', 'stereo'] as const) if (typeof sample[key] === 'boolean') attrs[key] = String(sample[key])
  return attrs
}
export function createAudioTelemetryReporter(now = () => performance.now()): (snapshot: VoiceAudioDiagnostics) => void {
  let last = -Infinity
  return (snapshot) => {
    if (now() - last < 10000) return
    last = now()
    // At most two anonymous samples per window; worst receiver loss is actionable.
    const sender = snapshot.samples.find((sample) => sample.direction === 'sender')
    const receiver = snapshot.samples.filter((sample) => sample.direction === 'receiver')
      .sort((a, b) => (b.lossPercent ?? -1) - (a.lossPercent ?? -1))[0]
    for (const sample of [sender, receiver]) {
      if (!sample) continue
      const span = trace.getTracer('boohtacord/web').startSpan('voice.audio.sample', { kind: SpanKind.CLIENT })
      span.setAttributes(audioTelemetryAttributes(snapshot.profile, sample))
      span.end()
    }
  }
}
