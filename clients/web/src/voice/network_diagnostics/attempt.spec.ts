import { expect, it } from 'vitest'
import { NetworkAttempt } from './attempt'
it('separates signal/ICE/join and requires counter growth for observed RTP', () => {
  let now = 100
  const attempt = new NetworkAttempt(() => now)
  attempt.start(); now = 120; attempt.signal(); now = 140; attempt.ice(); now = 160; attempt.connected()
  attempt.observe({ audioBytesSent: null, audioBytesReceived: 100 })
  expect(attempt.snapshot().firstRtpObservedMs).toBeNull()
  now = 200; attempt.observe({ audioBytesSent: null, audioBytesReceived: 200 })
  expect(attempt.snapshot()).toMatchObject({ signalMs: 20, iceObservedMs: 40, sdkJoinMs: 60, firstRtpObservedMs: 100, outcome: 'connected' })
  attempt.start()
  expect(attempt.snapshot().firstRtpObservedMs).toBeNull()
})
it('does not infer ICE/media from signal and does not overwrite failure on disconnect', () => {
  const attempt = new NetworkAttempt(() => 10)
  attempt.start(); attempt.signal(); attempt.failed(); attempt.disconnected()
  expect(attempt.snapshot()).toMatchObject({ outcome: 'failed', signalMs: 0, iceObservedMs: null, firstRtpObservedMs: null })
})
