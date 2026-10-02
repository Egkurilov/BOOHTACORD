import { postScreenClientReport, webPlatform } from '../screen_client_reporter'
import type { VoiceConnectionStats } from '../voice_connection_quality'

// Called only after a fresh room sample. No retry queue survives a logout.
export function createConnectionReporter() {
  let last = -Infinity
  let busy = false
  return (stats: VoiceConnectionStats): void => {
    if (busy || Date.now() - last < 5000) return
    last = Date.now()
    busy = true
    void postScreenClientReport({ platform: webPlatform(navigator.userAgent), direction: 'connection', state: 'playing',
      connection_quality: stats.quality, sample_age_ms: 0,
      ...(stats.pingMs === null ? {} : { rtt_ms: stats.pingMs }),
    }).catch(() => {}).finally(() => { busy = false })
  }
}
