const sampleWindowMs = 2000

/** Measures frames presented by this viewer, not the publisher's target FPS. */
export function observeScreenPlaybackFps(video: HTMLVideoElement, onSample: (fps: number | null) => void, onFirstFrame?: () => void,onCounter?:(frames:number|null)=>void, onFirstFrameTime?: (elapsedMs: number) => void): () => void {
  if (typeof video.requestVideoFrameCallback !== 'function' || typeof video.cancelVideoFrameCallback !== 'function') {
    onSample(null)
    return () => {}
  }

  let stopped = false
  let requestId: number | null = null
  let observedFrame = false
  let framesInWindow = 0
  let previousPresentedFrames: number | null = null
  const startedAt = performance.now()
  let windowStartedAt = startedAt

  function onFrame(_now: DOMHighResTimeStamp, metadata: VideoFrameCallbackMetadata): void {
    if (stopped) return
    if (!observedFrame) { onFirstFrame?.(); onFirstFrameTime?.(Math.max(0, performance.now() - startedAt)) }
    observedFrame = true
    const presentedFrames = metadata.presentedFrames
    const validCounter = Number.isFinite(presentedFrames) && presentedFrames >= 0
    if (validCounter && previousPresentedFrames !== null && presentedFrames < previousPresentedFrames) { framesInWindow = 0; windowStartedAt = performance.now() }
    framesInWindow += validCounter && previousPresentedFrames !== null && presentedFrames >= previousPresentedFrames
      ? presentedFrames - previousPresentedFrames
      : 1
    previousPresentedFrames = validCounter ? presentedFrames : null
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
    onCounter?.(previousPresentedFrames)
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
