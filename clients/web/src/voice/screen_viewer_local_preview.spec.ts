import { describe, expect, it, vi } from 'vitest'

import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'

function localStream(): ScreenViewerStream {
  return {
    hasAudio: false,
    id: 'self',
    isLocal: true,
    participantId: 'self',
    participantName: 'Ваш экран',
    video: { track: { attach: vi.fn(), detach: vi.fn() } },
  }
}

describe('local screen preview', () => {
  it('plays the owner preview without subscribing to it or routing its audio', () => {
    const local = localStream()
    const attachAudio = vi.fn()
    const controller = new ScreenViewerController(() => [local], { attach: attachAudio } as never)
    const videoElement = {} as HTMLVideoElement

    controller.select(local.id, videoElement, {} as HTMLAudioElement)

    expect('setSubscribed' in local.video).toBe(false)
    expect(local.video.track!.attach).toHaveBeenCalledWith(videoElement)
    expect(attachAudio).not.toHaveBeenCalled()
    expect(controller.cards()[0]?.isLocal).toBe(true)
  })

  it('returns to the voice room when the local publication stops', () => {
    const local = localStream()
    const streams: ScreenViewerStream[] = [local]
    const controller = new ScreenViewerController(() => streams)

    controller.select(local.id, {} as HTMLVideoElement, {} as HTMLAudioElement)
    streams.splice(0)
    controller.reconcile()

    expect(controller.selectedId).toBeNull()
    expect(controller.ended).toBe(false)
  })
})
