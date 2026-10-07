import { screenProfile, screenShareMaxBitrate, type ScreenProfile } from '../screen_profile/policy'

export type ScreenProfileCeiling = 720 | 1080 | 1440
export type ScreenSharePreferenceStorage = Pick<Storage, 'getItem' | 'setItem'>

export function screenProfileMode(profile: ScreenProfile): 'motion' | 'text' {
  return screenProfile(profile).frameRate === 60 ? 'motion' : 'text'
}

export function screenShareLayerBudget(profile: ScreenProfile): { primaryBps: number; secondaryBps: number; totalBps: number } {
  const { height, frameRate, bitrate } = screenProfile(profile)
  const primaryBps = screenShareMaxBitrate(height, frameRate)
  const secondaryBps = Math.max(150_000, Math.floor(bitrate / (4 * (frameRate / 15))))
  return { primaryBps, secondaryBps, totalBps: primaryBps + secondaryBps }
}

export function screenShareBandwidthEstimate(profile: ScreenProfile): string {
  const budget = screenShareLayerBudget(profile)
  return `основной слой до ${formatBitrate(budget.primaryBps)}; максимум для двух слоёв до ${formatBitrate(budget.totalBps)}`
}

export function screenProfilePreferenceKey(originId: string, accountId: string): string {
  return `boohtacord.screen-share.v1:${encodeURIComponent(originId)}:${encodeURIComponent(accountId)}`
}

export function readScreenProfilePreference(
  storage: ScreenSharePreferenceStorage | undefined, originId: string, accountId: string,
): ScreenProfile | undefined {
  if (!storage || !originId || !accountId) return undefined
  try {
    const value = storage.getItem(screenProfilePreferenceKey(originId, accountId))
    return value && /^P(720|1080|1440)_(15|30|60)$/.test(value) ? value as ScreenProfile : undefined
  } catch { return undefined }
}

export function saveScreenProfilePreference(
  storage: ScreenSharePreferenceStorage | undefined, originId: string, accountId: string, profile: ScreenProfile,
): void {
  if (!storage || !originId || !accountId || !/^P(720|1080|1440)_(15|30|60)$/.test(profile)) return
  try { storage.setItem(screenProfilePreferenceKey(originId, accountId), profile) } catch { /* Preferences remain optional. */ }
}

export function screenSampleAge(sampledAt: number | null, now = Date.now()): string {
  if (sampledAt === null || !Number.isFinite(sampledAt)) return 'Нет свежих данных'
  const seconds = Math.max(0, Math.floor((now - sampledAt) / 1000))
  if (seconds <= 1) return 'Обновлено только что'
  if (seconds > 15) return `Данные устарели · ${seconds} с назад`
  return `Обновлено ${seconds} с назад`
}

function formatBitrate(bps: number): string {
  return bps >= 1_000_000 ? `≈ ${(bps / 1_000_000).toFixed(1)} Мбит/с` : `≈ ${Math.round(bps / 1_000)} Кбит/с`
}
