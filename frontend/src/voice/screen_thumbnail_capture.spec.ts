import { afterEach, describe, expect, it, vi } from 'vitest'

import { captureScreenThumbnailFromTrack } from './screen_thumbnail'

function video(readyState = 2): HTMLVideoElement {
  return {
    autoplay: false,
    muted: false,
    playsInline: false,
    readyState,
    videoHeight: 720,
    videoWidth: 1280,
    play: vi.fn(async () => undefined),
    pause: vi.fn(),
  } as unknown as HTMLVideoElement
}

describe('remote screen thumbnail capture', () => {
  afterEach(() => vi.useRealTimers())

  it('captures one bounded JPEG after the video has a decoded frame and detaches', async () => {
    const element = video()
    const track = { attach: vi.fn(), detach: vi.fn() }
    const onThumbnail = vi.fn()
    const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xd9])

    const captured = await captureScreenThumbnailFromTrack(track, onThumbnail, {
      createVideo: () => element,
      captureFrame: vi.fn(async () => bytes),
    })

    expect(captured).toBe(true)
    expect(track.attach).toHaveBeenCalledWith(element)
    expect(onThumbnail).toHaveBeenCalledWith(bytes)
    expect(track.detach).toHaveBeenCalledWith(element)
    expect(element.pause).toHaveBeenCalledOnce()
  })

  it('does not capture after the room or publication becomes inactive', async () => {
    const element = video()
    const captureFrame = vi.fn(async () => new Uint8Array([0xff, 0xd8, 0xff, 0xd9]))
    const track = { attach: vi.fn(), detach: vi.fn() }

    const captured = await captureScreenThumbnailFromTrack(track, vi.fn(), {
      createVideo: () => element,
      captureFrame,
      isActive: () => false,
    })

    expect(captured).toBe(false)
    expect(captureFrame).not.toHaveBeenCalled()
    expect(track.detach).toHaveBeenCalledWith(element)
  })

  it('detaches safely when the browser rejects playback setup', async () => {
    const element = video()
    element.play = vi.fn(() => { throw new Error('playback unavailable') })
    const track = { attach: vi.fn(), detach: vi.fn() }

    const captured = await captureScreenThumbnailFromTrack(track, vi.fn(), {
      createVideo: () => element,
    })

    expect(captured).toBe(false)
    expect(track.detach).toHaveBeenCalledWith(element)
    expect(element.pause).toHaveBeenCalledOnce()
  })

  it('stops retrying after the bounded decoded-frame wait', async () => {
    vi.useFakeTimers()
    const element = video(0)
    const captureFrame = vi.fn(async () => new Uint8Array([0xff, 0xd8, 0xff, 0xd9]))
    const track = { attach: vi.fn(), detach: vi.fn() }
    const capture = captureScreenThumbnailFromTrack(track, vi.fn(), {
      createVideo: () => element,
      captureFrame,
      attempts: 3,
      retryIntervalMs: 250,
    })

    await vi.advanceTimersByTimeAsync(500)

    expect(await capture).toBe(false)
    expect(captureFrame).not.toHaveBeenCalled()
    expect(track.detach).toHaveBeenCalledWith(element)
  })
})
