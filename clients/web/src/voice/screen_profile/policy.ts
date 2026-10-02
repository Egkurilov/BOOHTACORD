export type ScreenResolution = 720 | 1080 | 1440
export type ScreenFrameRate = 15 | 30 | 60
export type ScreenProfile = `P${ScreenResolution}_${ScreenFrameRate}`

const bitrates: Record<ScreenResolution, Record<ScreenFrameRate, number>> = {
  720: { 15: 1_500_000, 30: 2_500_000, 60: 4_000_000 },
  1080: { 15: 2_500_000, 30: 5_000_000, 60: 8_000_000 },
  1440: { 15: 5_000_000, 30: 8_000_000, 60: 12_000_000 },
}
export function screenShareMaxBitrate(resolution: ScreenResolution, frameRate: ScreenFrameRate): number {
  return bitrates[resolution][frameRate]
}
export function screenProfile(profile: ScreenProfile) {
  const match = /^P(720|1080|1440)_(15|30|60)$/.exec(profile)
  if (!match) throw new Error('Некорректный профиль демонстрации.')
  const height = Number(match[1]) as ScreenResolution, frameRate = Number(match[2]) as ScreenFrameRate
  return { width: height === 720 ? 1280 : height === 1080 ? 1920 : 2560, height, frameRate, bitrate: bitrates[height][frameRate] }
}
export function profileDimensions(profile: ScreenProfile, settings: MediaTrackSettings) {
  const target = screenProfile(profile)
  return (settings.height ?? 0) > (settings.width ?? 0)
    ? { width: target.height, height: target.width } : { width: target.width, height: target.height }
}
export function profileScale(profile: ScreenProfile, settings: MediaTrackSettings): number {
  const target = profileDimensions(profile, settings)
  return Math.max(1, (settings.width ?? 0) / target.width, (settings.height ?? 0) / target.height)
}
