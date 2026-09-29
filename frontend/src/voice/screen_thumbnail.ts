export const screenThumbnailTopic = 'boohtacord.screen.thumbnail.v1'
const maxBytes = 14 * 1024

export function validScreenThumbnail(bytes: Uint8Array): boolean {
  return bytes.length >= 4 && bytes.length <= maxBytes &&
    bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[bytes.length - 2] === 0xff && bytes[bytes.length - 1] === 0xd9
}

interface ThumbnailVideoTrack {
  attach(element: HTMLVideoElement): unknown
  detach(element: HTMLVideoElement): unknown
}

interface ThumbnailPublisher {
  publishData(bytes: Uint8Array, options: { topic: string; reliable: boolean }): Promise<void>
}

export function publishScreenThumbnails(track: ThumbnailVideoTrack, publisher: ThumbnailPublisher, onThumbnail?: (bytes: Uint8Array) => void): () => void {
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
      const canvas = document.createElement('canvas')
      const context = canvas.getContext('2d')
      if (!context) return
      let blob: Blob | null = null
      for (const [width, quality] of [[160, 0.45], [128, 0.35], [96, 0.25]] as const) {
        canvas.width = width
        canvas.height = Math.max(1, Math.round(video.videoHeight * width / video.videoWidth))
        context.drawImage(video, 0, 0, canvas.width, canvas.height)
        blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, 'image/jpeg', quality))
        if (blob && blob.size <= maxBytes) break
      }
      if (!blob || !active || blob.size > maxBytes) return
      const bytes = new Uint8Array(await blob.arrayBuffer())
      if (validScreenThumbnail(bytes) && active) {
        onThumbnail?.(bytes)
        await publisher.publishData(bytes, { topic: screenThumbnailTopic, reliable: true })
      }
    } catch {
      // A preview failure must not interrupt the live screen track.
    } finally { busy = false }
  }
  const timer = setInterval(() => { void sample() }, 4_000)
  void sample()
  return () => { active = false; clearInterval(timer); track.detach(video); video.pause() }
}
