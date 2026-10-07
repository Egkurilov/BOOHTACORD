const maxBytes = 14 * 1024
const thumbnailWidths = [160, 128, 96] as const

export interface LocalScreenThumbnailTrack {
  attach(element: HTMLVideoElement): unknown
  detach(element: HTMLVideoElement): unknown
}

export function validScreenThumbnail(bytes: Uint8Array): boolean {
  return bytes.length >= 4 && bytes.length <= maxBytes &&
    bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[bytes.length - 2] === 0xff && bytes[bytes.length - 1] === 0xd9
}

export function captureLocalScreenThumbnails(
  track: LocalScreenThumbnailTrack,
  onThumbnail: (bytes: Uint8Array) => void,
): () => void {
  const video = document.createElement('video')
  video.autoplay = true
  video.muted = true
  video.playsInline = true
  track.attach(video)
  void video.play().catch(() => undefined)
  let active = true
  let busy = false
  async function sample(): Promise<void> {
    if (!active || busy || video.readyState < 2 || !video.videoWidth || !video.videoHeight) return
    busy = true
    try {
      const bytes = await captureVideoFrame(video)
      if (bytes && active) onThumbnail(bytes)
    } catch {
      // A preview failure must not interrupt the live screen track.
    } finally { busy = false }
  }
  const timer = setInterval(() => { void sample() }, 4_000)
  void sample()
  return () => { active = false; clearInterval(timer); track.detach(video); video.pause() }
}

async function captureVideoFrame(video: HTMLVideoElement): Promise<Uint8Array | null> {
  const canvas = document.createElement('canvas')
  const context = canvas.getContext('2d')
  if (!context) return null
  let blob: Blob | null = null
  for (const width of thumbnailWidths) {
    canvas.width = width
    canvas.height = Math.max(1, Math.round(video.videoHeight * width / video.videoWidth))
    context.drawImage(video, 0, 0, canvas.width, canvas.height)
    blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.45))
    if (blob && blob.size <= maxBytes) break
  }
  if (!blob || blob.size > maxBytes) return null
  const bytes = new Uint8Array(await blob.arrayBuffer())
  return validScreenThumbnail(bytes) ? bytes : null
}
