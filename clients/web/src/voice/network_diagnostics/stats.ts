import { safeNumber, type NetworkTransport, type RawNetworkStat } from './model'
export const candidateType = (value: unknown): NetworkTransport['localType'] =>
  value === 'host' || value === 'srflx' || value === 'prflx' || value === 'relay' ? value : null
export const protocol = (value: unknown): NetworkTransport['protocol'] => value === 'udp' || value === 'tcp' ? value : null
export function projectTransport(reports: Iterable<RawNetworkStat>): NetworkTransport {
  const stats = [...reports]
  const selected = stats.filter(stat => stat.type === 'transport').map(stat => stat.selectedCandidatePairId).filter(Boolean)
  const pairs = stats.filter(stat => stat.type === 'candidate-pair' && selected.includes(stat.id) && stat.state === 'succeeded')
  const pair = pairs.length === 1 ? pairs[0] : undefined
  const local = pair && stats.find(stat => stat.type === 'local-candidate' && stat.id === pair.localCandidateId)
  const remote = pair && stats.find(stat => stat.type === 'remote-candidate' && stat.id === pair.remoteCandidateId)
  const seconds = safeNumber(pair?.currentRoundTripTime)
  const sum = (direction: string, key: 'bytesSent' | 'bytesReceived') => {
    const values = stats.filter(stat => stat.type === direction && (stat.kind ?? stat.mediaType) === 'audio').map(stat => safeNumber(stat[key]))
    return values.length && values.every(value => value !== null) ? safeNumber(values.reduce<number>((total, value) => total + value!, 0)) : null
  }
  return { selected: Boolean(pair), protocol: protocol(local?.protocol), localType: candidateType(local?.candidateType),
    remoteType: candidateType(remote?.candidateType), rttMs: seconds !== null && seconds <= 60 ? seconds * 1000 : null,
    audioBytesSent: sum('outbound-rtp', 'bytesSent'), audioBytesReceived: sum('inbound-rtp', 'bytesReceived') }
}
