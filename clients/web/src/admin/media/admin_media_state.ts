import type { AdminScreenSample } from './admin_media_client'

export type AdminMediaState = 'empty' | 'stale' | 'populated' | 'error'
export function isFreshSample(sample: AdminScreenSample, now: number): boolean {
  const sampledAt = Date.parse(sample.sampled_at_utc)
  return sampledAt >= now - 60_000 && sampledAt <= now + 5_000
}

export function selectAdminMediaState(samples: AdminScreenSample[], now: number, lastSeenAt: number | null, error: string | null): { kind: AdminMediaState; freshCount: number } {
  const freshCount = samples.filter((sample) => isFreshSample(sample, now)).length
  if (error) return { kind: 'error', freshCount }
  if (freshCount) return { kind: 'populated', freshCount }
  return { kind: samples.length || lastSeenAt !== null ? 'stale' : 'empty', freshCount: 0 }
}
