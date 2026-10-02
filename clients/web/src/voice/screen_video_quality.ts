type ScreenVideoDimensions = Pick<HTMLVideoElement, 'videoHeight' | 'videoWidth'> | null

export function formatScreenVideoQuality(video: ScreenVideoDimensions, playbackFps: number | null = null): string {
  const width = video?.videoWidth ?? 0
  const height = video?.videoHeight ?? 0
  if (width <= 0 || height <= 0) return 'Определяем качество…'
  const fps = playbackFps !== null && Number.isFinite(playbackFps) && playbackFps >= 0
    ? `${playbackFps} FPS у зрителя`
    : 'FPS не определена'
  return `${width} × ${height} · ${fps}`
}
