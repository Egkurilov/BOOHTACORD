import { expect, test } from '@playwright/test'
import { sanitizeTrackStats } from './stats'

test('track samples keep numeric WebRTC metrics, strip candidate identifiers, and preserve unavailable fields', () => {
  const report = new Map<string, any>([
    ['outbound', { id: 'outbound-private', type: 'outbound-rtp', kind: 'video', rid: 'single', codecId: 'codec-private', mediaSourceId: 'source-private', frameWidth: 1920, frameHeight: 1080, framesEncoded: 60, bytesSent: 8000, packetsSent: 72, packetsLost: 1, jitter: 0.02, totalEncodeTime: 0.4 }],
    ['inbound', { id: 'inbound-private', type: 'inbound-rtp', kind: 'video', codecId: 'codec-private', framesDecoded: 58, framesDropped: 2, bytesReceived: 7900, packetsReceived: 70, totalDecodeTime: 0.2, freezeCount: 1 }],
    ['codec-private', { id: 'codec-private', type: 'codec', mimeType: 'video/VP8' }],
    ['source-private', { id: 'source-private', type: 'media-source', frames: 60, framesPerSecond: 60 }],
    ['pair-private', { id: 'pair-private', type: 'candidate-pair', selected: true, localCandidateId: 'local-private', remoteCandidateId: 'remote-private', currentRoundTripTime: 0.04, availableOutgoingBitrate: 8000000 }],
    ['local-private', { id: 'local-private', type: 'local-candidate', protocol: 'udp', candidateType: 'host', address: '192.0.2.4' }],
    ['remote-private', { id: 'remote-private', type: 'remote-candidate', protocol: 'udp', candidateType: 'relay', address: '198.51.100.7' }],
  ]) as unknown as RTCStatsReport

  const sender = sanitizeTrackStats(report, 'outbound')
  const receiver = sanitizeTrackStats(report, 'inbound')
  expect(sender.layers[0]).toMatchObject({ codec: 'video/VP8', frames: 60, frameWidth: 1920, sourceFramesPerSecond: 60, packets: 72, packetsLost: 1, jitter: 0.02, totalEncodeTime: 0.4 })
  expect(receiver.layers[0]).toMatchObject({ codec: 'video/VP8', frames: 58, framesDropped: 2, bytes: 7900, packets: 70, totalDecodeTime: 0.2, freezeCount: 1 })
  expect(sender.candidateProtocol).toBe('udp')
  expect(sender.currentRoundTripTime).toBe(0.04)
  expect(sender.availableOutgoingBitrate).toBe(8000000)
  expect(receiver.remoteCandidateType).toBe('relay')
  expect(JSON.stringify({ sender, receiver })).not.toMatch(/192\.0\.2\.4|198\.51\.100\.7|private/)
  const unavailableReport = new Map<string, any>([
    ['out', { id: 'out', type: 'outbound-rtp', kind: 'video' }],
  ]) as unknown as RTCStatsReport
  expect(sanitizeTrackStats(unavailableReport, 'outbound').layers[0]).toMatchObject({ frames: null, totalEncodeTime: null, sourceFramesPerSecond: null })
})
