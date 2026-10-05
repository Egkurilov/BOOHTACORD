import { describe, expect, it } from 'vitest'
import { projectTransport } from './stats'
describe('private selected transport projection', () => {
  it('uses the transport-selected pair rather than any nominated pair', () => {
    const stats = [
      { type: 'transport', selectedCandidatePairId: 'chosen' },
      { type: 'candidate-pair', id: 'other', nominated: true, state: 'succeeded', localCandidateId: 'wrong' },
      { type: 'candidate-pair', id: 'chosen', state: 'succeeded', localCandidateId: 'local', remoteCandidateId: 'remote', currentRoundTripTime: 0.025 },
      { type: 'local-candidate', id: 'local', protocol: 'udp', candidateType: 'host', address: 'private-address', port: 7882 },
      { type: 'remote-candidate', id: 'remote', protocol: 'udp', candidateType: 'srflx' },
      { type: 'local-candidate', id: 'wrong', protocol: 'tcp' },
      { type: 'inbound-rtp', kind: 'audio', bytesReceived: 1200 },
    ]
    expect(projectTransport(stats)).toEqual({ selected: true, protocol: 'udp', localType: 'host', remoteType: 'srflx', rttMs: 25, audioBytesSent: null, audioBytesReceived: 1200 })
    expect(JSON.stringify(projectTransport(stats))).not.toContain('private-address')
  })
  it('keeps absent/ambiguous/invalid values unknown', () => {
    expect(projectTransport([{ type: 'candidate-pair', nominated: true, state: 'succeeded' }]).selected).toBe(false)
    expect(projectTransport([{ type: 'inbound-rtp', kind: 'audio', bytesReceived: NaN }]).audioBytesReceived).toBeNull()
    expect(projectTransport([]).protocol).toBeNull()
  })
})
