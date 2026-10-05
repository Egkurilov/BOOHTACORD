export interface NetworkTransport {
  selected: boolean
  protocol: 'udp' | 'tcp' | null
  localType: 'host' | 'srflx' | 'prflx' | 'relay' | null
  remoteType: NetworkTransport['localType']
  rttMs: number | null
  audioBytesSent: number | null
  audioBytesReceived: number | null
}
export interface NetworkDiagnostics {
  outcome: 'idle' | 'connecting' | 'connected' | 'failed' | 'disconnected'
  signalMs: number | null
  iceObservedMs: number | null
  sdkJoinMs: number | null
  firstRtpObservedMs: number | null
  elapsedMs: number | null
  transports: NetworkTransport[]
}
export const safeNumber = (value: unknown): number | null =>
  typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= Number.MAX_SAFE_INTEGER ? value : null
export interface RawNetworkStat {
  type?: string; id?: string; selectedCandidatePairId?: string
  localCandidateId?: string; remoteCandidateId?: string; state?: string; nominated?: boolean
  protocol?: unknown; candidateType?: unknown; currentRoundTripTime?: unknown
  kind?: string; mediaType?: string; bytesSent?: unknown; bytesReceived?: unknown
}
