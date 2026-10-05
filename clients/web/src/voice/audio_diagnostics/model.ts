export type AudioDirection = 'sender' | 'receiver'
export type RawAudioStat = Record<string, unknown>
export interface AudioSample {
  direction: AudioDirection
  codec: string | null
  transportCodec: string | null
  codecChannels: number | null
  clockRate: number | null
  red: boolean | null
  dtx: boolean | null
  fec: boolean | null
  stereo: boolean | null
  bitrateBps: number | null
  intervalMs: number | null
  packets: number | null
  jitterMs: number | null
  lossPercent: number | null
  concealedSamples: number | null
  concealmentEvents: number | null
  audioLevel: number | null
}
export interface VoiceAudioDiagnostics {
  profile: string
  capBps: number
  capture: { sampleRate: number | null; channels: number | null; agc: boolean | null; aec: boolean | null; ns: boolean | null }
  samples: AudioSample[]
}
export function statNumber(value: unknown): number | null {
  if (typeof value !== 'number' && typeof value !== 'string') return null
  if (typeof value === 'string' && value.trim() === '') return null
  const number = Number(value)
  return Number.isFinite(number) && number >= 0 ? number : null
}
export { exportVoiceAudioDiagnostics } from '../audio_report/export'
