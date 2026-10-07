import contract from '../../../../../contracts/screen-share-profile-v1.catalog.json'

export type ScreenResolution = 720 | 1080 | 1440
export type ScreenFrameRate = 15 | 30 | 60
export type ScreenProfile = `P${ScreenResolution}_${ScreenFrameRate}`

const bitrates = contract.existingProfiles.reduce<Partial<Record<ScreenResolution, Partial<Record<ScreenFrameRate, number>>>>>((table, profile) => {
  const resolution = profile.resolution as ScreenResolution
  const frameRate = profile.frameRate as ScreenFrameRate
  const rates = table[resolution] ?? {}
  rates[frameRate] = profile.bitrateBps
  table[resolution] = rates
  return table
}, {})

const resolutionSizes = Object.fromEntries(contract.resolutions.map(({ height, width }) => [height, width])) as Record<ScreenResolution, number>

export function screenShareMaxBitrate(resolution: ScreenResolution, frameRate: ScreenFrameRate): number {
  const bitrate = bitrates[resolution]?.[frameRate]
  if (bitrate === undefined) throw new Error('Некорректный профиль демонстрации.')
  return bitrate
}
export function screenProfile(profile: ScreenProfile) {
  const match = /^P(720|1080|1440)_(15|30|60)$/.exec(profile)
  if (!match) throw new Error('Некорректный профиль демонстрации.')
  const height = Number(match[1]) as ScreenResolution, frameRate = Number(match[2]) as ScreenFrameRate
  return { width: resolutionSizes[height], height, frameRate, bitrate: screenShareMaxBitrate(height, frameRate) }
}
export function profileDimensions(profile: ScreenProfile, settings: MediaTrackSettings) {
  const target = screenProfile(profile)
  return (settings.height ?? 0) > (settings.width ?? 0)
    ? { width: target.height, height: target.width } : { width: target.width, height: target.height }
}
export function profileScale(profile: ScreenProfile, settings: MediaTrackSettings): number {
  const target = profileDimensions(profile, settings)
  const width = settings.width ?? 0, height = settings.height ?? 0
  const scale = Math.max(1, width / target.width, height / target.height)
  if (width < 2 || height < 2) return scale

  const sourceLongEdge = Math.max(width, height)
  const largestEncodedEdge = Math.floor(sourceLongEdge / scale)
  for (let reduction = 0; reduction <= 30; reduction++) {
    const encodedLongEdge = largestEncodedEdge - reduction
    if (encodedLongEdge < 2) break
    const evenScale = sourceLongEdge / encodedLongEdge
    const encodedWidth = Math.floor(width / evenScale), encodedHeight = Math.floor(height / evenScale)
    if (encodedWidth % 2 === 0 && encodedHeight % 2 === 0 && encodedWidth <= target.width && encodedHeight <= target.height) return evenScale
  }
  return scale
}
