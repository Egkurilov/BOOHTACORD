import { voiceAudioProfiles } from '../audio_profile/generated'
import type { VoiceAudioDiagnostics } from '../audio_diagnostics/model'
const codecs = new Set(['opus', 'red', 'pcmu', 'pcma', 'g722', 'cn', 'other'])
const number = (value: unknown, max = Number.MAX_SAFE_INTEGER): number | null =>
  typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= max ? value : null
const flag = (value: unknown): boolean | null => typeof value === 'boolean' ? value : null
const codec = (value: unknown): string | null => typeof value === 'string' && codecs.has(value) ? value : null
export function exportVoiceAudioDiagnostics(value: VoiceAudioDiagnostics): string {
  const capture = value.capture as unknown as Record<string, unknown>
  const safeCapture: Record<string, unknown> = {}
  for (const key of ['sampleRate', 'channels', 'processingSampleRate', 'processingChannels'])
    safeCapture[key] = number(capture[key], key.includes('Rate') ? 192000 : 8)
  for (const key of ['agc', 'aec', 'ns']) safeCapture[key] = flag(capture[key])
  if (capture.source === 'unavailable') safeCapture.source = 'unavailable'
  const samples = value.samples.filter(({ direction }) => direction === 'sender' || direction === 'receiver').map((sample) => {
    const safe: Record<string, unknown> = { direction: sample.direction, codec: codec(sample.codec), transportCodec: codec(sample.transportCodec) }
    for (const key of ['codecChannels', 'clockRate', 'bitrateBps', 'intervalMs', 'packets', 'jitterMs', 'lossPercent', 'concealedSamples', 'concealmentEvents'] as const)
      safe[key] = number(sample[key])
    for (const key of ['red', 'dtx', 'fec', 'stereo'] as const) safe[key] = flag(sample[key])
    return safe
  })
  return JSON.stringify({
    profile: voiceAudioProfiles.some(({ id }) => id === value.profile) ? value.profile : 'unknown',
    capBps: number(value.capBps, 512000), capture: safeCapture, samples,
  }, null, 2)
}
