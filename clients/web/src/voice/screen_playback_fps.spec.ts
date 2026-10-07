import { readFileSync } from 'node:fs'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { observeScreenPlaybackFps } from './screen_playback_fps'
function videoFrames() {
  let callback: VideoFrameRequestCallback | undefined
  const cancel = vi.fn()
  const video = {
    cancelVideoFrameCallback: cancel,
    requestVideoFrameCallback: vi.fn((next: VideoFrameRequestCallback) => { callback = next; return 7 }),
  } as unknown as HTMLVideoElement
  return { cancel, emitFrame: (presentedFrames?: number) => callback?.(0, { presentedFrames } as VideoFrameCallbackMetadata), video }
}
afterEach(() => vi.useRealTimers())
describe('viewer screen playback FPS', () => {
  it('binds observation to the selected stream and releases it on unmount', () => {
    const viewer = readFileSync(new URL('./ScreenViewer.vue', import.meta.url), 'utf8')
    const binding = readFileSync(new URL('./screen_playback_quality.ts', import.meta.url), 'utf8')
    expect(viewer).toContain('useScreenPlaybackQuality(video, () => props.selectedId, () => props.ended)')
    expect(binding).toContain('watch([video, selectedId, ended], restartPlaybackObservation')
    expect(binding).toContain('stopObservingPlayback?.()')
    expect(binding).toContain('playbackFps.value = null')
    expect(binding).toContain('formatScreenVideoQuality(videoReady.value ? video.value : null, playbackFps.value)')
  })

  it('keeps no-data until the first presented frame, instead of reporting a false zero', () => {
    vi.useFakeTimers()
    const frames = videoFrames()
    const samples: Array<number | null> = []
    const stop = observeScreenPlaybackFps(frames.video, (fps) => samples.push(fps))

    vi.advanceTimersByTime(2000)
    expect(samples).toEqual([null])
    frames.emitFrame()
    vi.advanceTimersByTime(2000)
    expect(samples).toEqual([null, 0.5])
    stop()
  })

  it('signals the first presented frame even when loadeddata never fires', () => {
    const frames = videoFrames()
    const onFirstFrame = vi.fn()
    const stop = observeScreenPlaybackFps(frames.video, vi.fn(), onFirstFrame)
    expect(onFirstFrame).not.toHaveBeenCalled()
    frames.emitFrame(1)
    frames.emitFrame(2)
    expect(onFirstFrame).toHaveBeenCalledTimes(1)
    stop()
    frames.emitFrame(3)
    expect(onFirstFrame).toHaveBeenCalledTimes(1)
  })

  it('reports observed frames per second over a timed window, including a frozen stream', () => {
    vi.useFakeTimers()
    const frames = videoFrames()
    const samples: Array<number | null> = []
    const stop = observeScreenPlaybackFps(frames.video, (fps) => samples.push(fps))

    frames.emitFrame()
    frames.emitFrame()
    vi.advanceTimersByTime(2000)
    expect(samples).toEqual([1])

    vi.advanceTimersByTime(2000)
    expect(samples).toEqual([1, 0])
    stop()
    expect(frames.cancel).toHaveBeenCalledWith(7)
    frames.emitFrame()
    stop()
    expect(frames.cancel).toHaveBeenCalledTimes(1)
    vi.advanceTimersByTime(2000)
    expect(samples).toEqual([1, 0])
  })

  it('counts compositor frames missed between callbacks', () => {
    vi.useFakeTimers()
    const frames = videoFrames()
    const samples: Array<number | null> = []
    const stop = observeScreenPlaybackFps(frames.video, (fps) => samples.push(fps))
    frames.emitFrame(11)
    frames.emitFrame(15)
    vi.advanceTimersByTime(2000)
    expect(samples).toEqual([2.5])
    stop()
  })

  it('does not treat a compositor counter reset as a large frame jump', () => {
    vi.useFakeTimers()
    const frames = videoFrames()
    const samples: Array<number | null> = []
    const stop = observeScreenPlaybackFps(frames.video, (fps) => samples.push(fps))
    frames.emitFrame(10)
    frames.emitFrame(2)
    frames.emitFrame(3)
    vi.advanceTimersByTime(2000)
    expect(samples).toEqual([1])
    stop()
  })

  it('does not claim a frame rate when the browser cannot report presented frames', () => {
    const samples: Array<number | null> = []
    observeScreenPlaybackFps({} as HTMLVideoElement, (fps) => samples.push(fps))()
    expect(samples).toEqual([null])
  })
})


it('does not count duplicate compositor metadata and records first callback time', () => {
  vi.useFakeTimers()
  const frames = videoFrames(), samples: Array<number | null> = []
  const first = vi.fn()
  const stop = observeScreenPlaybackFps(frames.video, fps => samples.push(fps), undefined, undefined, first)
  vi.advanceTimersByTime(250)
  frames.emitFrame(10)
  frames.emitFrame(10)
  vi.advanceTimersByTime(1750)
  expect(samples).toEqual([0.5])
  expect(first).toHaveBeenCalledExactlyOnceWith(250)
  stop()
})
