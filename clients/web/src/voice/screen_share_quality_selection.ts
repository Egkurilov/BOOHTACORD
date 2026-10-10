import type { ScreenFrameRate, ScreenResolution } from './media_publishing'

export type ScreenShareQualityMode = 'motion' | 'text'
export type ScreenShareQualitySelection = {
  mode: ScreenShareQualityMode
  resolution: ScreenResolution
  frameRate: ScreenFrameRate
}

export function selectScreenQualityResolution(
  current: ScreenShareQualitySelection,
  resolution: ScreenResolution,
): ScreenShareQualitySelection {
  if (current.mode === 'motion' && resolution === 1440) {
    return { mode: 'text', resolution, frameRate: 30 }
  }
  return { ...current, resolution }
}

export function selectScreenQualityMode(
  current: ScreenShareQualitySelection,
  mode: ScreenShareQualityMode,
): ScreenShareQualitySelection {
  return {
    mode,
    frameRate: mode === 'motion' ? 60 : 30,
    resolution: mode === 'motion' && current.resolution === 1440 ? 1080 : current.resolution,
  }
}
