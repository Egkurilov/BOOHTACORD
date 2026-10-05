import { expect, it } from 'vitest'
import { exportNetworkDiagnostics } from './export'
it('rejects arbitrary strings and extra SDK fields in the public report', () => {
  const report = JSON.parse(exportNetworkDiagnostics({
    outcome: 'token-secret', signalMs: Infinity, sdkJoinMs: -1,
    address: 'private-address', token: 'token-secret',
    transports: [{ protocol: 'private-address', localType: 'token-secret', remoteType: 'relay', selected: true, rttMs: 2, sdp: 'secret', audioBytesSent: 4 }],
  } as any))
  expect(JSON.stringify(report)).not.toMatch(/private-address|token-secret|secret|address|sdp/)
  expect(report.outcome).toBe('unknown'); expect(report.signalMs).toBeNull()
  expect(report.transports[0].remoteType).toBe('relay')
})
