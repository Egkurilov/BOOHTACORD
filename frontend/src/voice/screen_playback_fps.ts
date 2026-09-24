const sampleWindowMs = 2000

/** Measures frames presented by this viewer, not the publisher's target FPS. */
export function observeScreenPlaybackFps(video: HTMLVideoElement, onSample: (fps: number | null) => void): () => void {
  if (typeof video.requestVideoFrameCallback !== 'function' || typeof video.cancelVideoFrameCallback !== 'function') {
    onSample(null)
    return () => {}
  }

  let stopped = false
  let requestId: number | null = null
  let observedFrame = false
  let framesInWindow = 0
  let windowStartedAt = performance.now()

  function onFrame(): void {
    if (stopped) return
    observedFrame = true
    framesInWindow += 1
    requestId = video.requestVideoFrameCallback(onFrame)
  }

  requestId = video.requestVideoFrameCallback(onFrame)
  const intervalId = globalThis.setInterval(() => {
    const now = performance.now()
    const elapsedMs = now - windowStartedAt
    const fps = observedFrame && elapsedMs > 0
      ? Math.round((framesInWindow * 1000 / elapsedMs) * 10) / 10
      : null
    onSample(fps)
    framesInWindow = 0
    windowStartedAt = now
  }, sampleWindowMs)

  return () => {
    if (stopped) return
    stopped = true
    globalThis.clearInterval(intervalId)
    if (requestId !== null) video.cancelVideoFrameCallback(requestId)
  }
}
