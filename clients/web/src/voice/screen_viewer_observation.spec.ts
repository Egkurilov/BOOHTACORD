import { ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { createScreenViewerControls } from './screen_viewer_controls'
import { ScreenViewerController, type ScreenViewerCard, type ScreenViewerStream } from './screen_viewer_controller'

function stream(id: string): ScreenViewerStream {
  return { id, participantId: id, participantName: id, hasAudio: false, video: { setSubscribed: vi.fn(), track: { attach: vi.fn(), detach: vi.fn() } } }
}

describe('screen viewer operation callbacks', () => {
  it('rejects late first-frame callbacks after A to B and after a publication generation ends', () => {
    const streams = [stream('a'), stream('b')]
    const callbacks: VideoFrameRequestCallback[] = []
    const video = {
      readyState: 2,
      requestVideoFrameCallback: vi.fn((callback: VideoFrameRequestCallback) => { callbacks.push(callback); return callbacks.length }),
      cancelVideoFrameCallback: vi.fn(),
    } as unknown as HTMLVideoElement
    const controller = new ScreenViewerController(() => streams)
    const attached = vi.spyOn(controller, 'hasAttachedVideo')
    const controls = createScreenViewerControls({ screenViewer: () => controller }, ref<ScreenViewerCard[]>([]), ref<string | null>(null), ref<string | null>(null), ref(false))
    controls.start()

    controls.select('a', video, null)
    const lateA = callbacks[0]!
    controls.select('b', video, null)
    lateA(1, {} as VideoFrameCallbackMetadata)
    expect(attached).not.toHaveBeenCalled()

    const lateB = callbacks[1]!
    streams[1] = stream('b')
    controller.reconcile()
    lateB(2, {} as VideoFrameCallbackMetadata)
    expect(controller.selectedId).toBeNull()
    expect(attached).not.toHaveBeenCalled()
    controls.stop()
  })

  it('starts a new first-frame observation when the same publication receives a replacement track', () => {
    const trackA = { attach: vi.fn(), detach: vi.fn() }
    const trackB = { attach: vi.fn(), detach: vi.fn() }
    const videoPublication = { setSubscribed: vi.fn(), track: trackA }
    const initial = stream('same')
    initial.video = videoPublication
    let current = initial
    const callbacks: VideoFrameRequestCallback[] = []
    const video = {
      readyState: 2,
      requestVideoFrameCallback: vi.fn((callback: VideoFrameRequestCallback) => { callbacks.push(callback); return callbacks.length }),
      cancelVideoFrameCallback: vi.fn(),
    } as unknown as HTMLVideoElement
    const controller = new ScreenViewerController(() => [current])
    const controls = createScreenViewerControls({ screenViewer: () => controller }, ref<ScreenViewerCard[]>([]), ref<string | null>(null), ref<string | null>(null), ref(false))
    controls.start()
    controls.select('same', video, null)
    const lateA = callbacks[0]!

    videoPublication.track = trackB
    current = { ...initial }
    controller.reconcile()
    expect(callbacks).toHaveLength(2)
    lateA(1, {} as VideoFrameCallbackMetadata)
    expect(trackB.attach).toHaveBeenCalledWith(video)
    expect(callbacks).toHaveLength(2)
    controls.stop()
  })
})
