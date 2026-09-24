type ScreenVideoDimensions = Pick<HTMLVideoElement, 'videoHeight' | 'videoWidth'> | null

export function formatScreenVideoQuality(video: ScreenVideoDimensions): string {
  const width = video?.videoWidth ?? 0
  const height = video?.videoHeight ?? 0
  return width > 0 && height > 0 ? `${width} × ${height} · FPS не определена` : 'Определяем качество…'
}
