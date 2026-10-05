import { safeNumber, type NetworkDiagnostics } from './model'
import { candidateType, protocol } from './stats'
const outcomes = new Set(['idle', 'connecting', 'connected', 'failed', 'disconnected'])
export function exportNetworkDiagnostics(value: NetworkDiagnostics): string {
  return JSON.stringify({
    outcome: outcomes.has(value.outcome) ? value.outcome : 'unknown',
    signalMs: safeNumber(value.signalMs), iceObservedMs: safeNumber(value.iceObservedMs),
    sdkJoinMs: safeNumber(value.sdkJoinMs), firstRtpObservedMs: safeNumber(value.firstRtpObservedMs), elapsedMs: safeNumber(value.elapsedMs),
    transports: (Array.isArray(value.transports) ? value.transports : []).slice(0, 2).map(transport => ({
      selected: transport.selected === true, protocol: protocol(transport.protocol),
      localType: candidateType(transport.localType), remoteType: candidateType(transport.remoteType),
      rttMs: safeNumber(transport.rttMs), audioBytesSent: safeNumber(transport.audioBytesSent), audioBytesReceived: safeNumber(transport.audioBytesReceived),
    })),
  }, null, 2)
}
