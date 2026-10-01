export type ScreenAudioTrackStatus = 'PRESENT' | 'ABSENT' | 'UNKNOWN'
export type ScreenConnectionQuality = 'EXCELLENT' | 'GOOD' | 'POOR' | 'LOST' | 'UNKNOWN'
export type ScreenSourceState = 'ACTIVE' | 'ENDED' | 'UNKNOWN'

export interface ScreenMeasurement {
  framesPerSecond?: number
  height: number
  width: number
}

export interface ScreenDiagnostics {
  sampledAt?: number
  senderStatsAvailable?: boolean
  senderDimensionsAvailable?: boolean
  packetLossPercent?: number | null
  packetLossWindowMs?: number | null
  adaptationReason?: string
  audioTrack: ScreenAudioTrackStatus
  bitrateBps?: number
  connectionQuality: ScreenConnectionQuality
  measured: ScreenMeasurement | null
  packetsLost?: number
  roundTripTimeMs?: number
  source: ScreenSourceState
}

export interface ScreenSenderStats {
  timestamp?: number
  streamId?: string
  packetsSent?: number
  frameHeight?: number
  frameWidth?: number
  framesPerSecond?: number
  packetsLost?: number
  qualityLimitationReason?: string
  roundTripTime?: number
}

export interface RawScreenDiagnostics {
  audioTrack: boolean
  bitrateBps?: number
  connectionQuality?: string
  readyState?: string
  sender?: ScreenSenderStats
  settings?: MediaTrackSettings
}

function positive(value: number | undefined): number | undefined {
  return value !== undefined && Number.isFinite(value) && value > 0 ? value : undefined
}

function nonNegative(value: number | undefined): number | undefined {
  return value !== undefined && Number.isFinite(value) && value >= 0 ? value : undefined
}

function quality(value: string | undefined): ScreenConnectionQuality {
  const known = value?.toUpperCase()
  return known === 'EXCELLENT' || known === 'GOOD' || known === 'POOR' || known === 'LOST' ? known : 'UNKNOWN'
}

export function normalizeScreenDiagnostics(input: RawScreenDiagnostics): ScreenDiagnostics {
  const videoAvailable = input.readyState !== undefined
  const width = positive(input.sender?.frameWidth) ?? positive(input.settings?.width)
  const height = positive(input.sender?.frameHeight) ?? positive(input.settings?.height)
  const framesPerSecond = nonNegative(input.sender?.framesPerSecond)
  const measured = width && height ? { width, height, ...(framesPerSecond !== undefined ? { framesPerSecond } : {}) } : null
  const packetsLost = nonNegative(input.sender?.packetsLost)
  const roundTripTime = nonNegative(input.sender?.roundTripTime)
  return {
    ...(nonNegative(input.bitrateBps) !== undefined ? { bitrateBps: nonNegative(input.bitrateBps) } : {}),
    ...(input.sender?.qualityLimitationReason ? { adaptationReason: input.sender.qualityLimitationReason } : {}),
    ...(packetsLost !== undefined ? { packetsLost } : {}),
    ...(roundTripTime !== undefined ? { roundTripTimeMs: Math.round(roundTripTime * 1000) } : {}),
    audioTrack: videoAvailable ? input.audioTrack ? 'PRESENT' : 'ABSENT' : 'UNKNOWN',
    connectionQuality: quality(input.connectionQuality),
    measured,
    source: input.readyState === 'ended' ? 'ENDED' : videoAvailable ? 'ACTIVE' : 'UNKNOWN',
  }
}

export function unknownScreenDiagnostics(): ScreenDiagnostics {
  return normalizeScreenDiagnostics({ audioTrack: false })
}
