import { describe, expect, it, vi } from 'vitest'

import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'

function stream(id = 'alice:screen'): ScreenViewerStream {
  return {
    hasAudio: true,
    id,
    participantId: id.split(':')[0]!,
    participantName: 'Alice',
    audio: { setSubscribed: vi.fn(), track: { attach: vi.fn(), detach: vi.fn() } },
    video: { setSubscribed: vi.fn(), track: { attach: vi.fn(), detach: vi.fn() } },
  }
}

describe('screen viewer publication lifecycle', () => {
  it('keeps the current binding stable across 100 reselects of one publication generation', () => {
    const selected = stream()
    const attachOutput = vi.fn(() => ({ dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }))
    const controller = new ScreenViewerController(() => [selected], { attach: attachOutput } as never)
    const video = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement

    controller.select(selected.id, video, audio)
    const operation = controller.operationGeneration
    for (let attempt = 0; attempt < 100; attempt += 1) controller.select(selected.id, video, audio)

    expect(controller.operationGeneration).toBe(operation)
    expect(selected.video.setSubscribed).toHaveBeenCalledTimes(1)
    expect(selected.audio!.setSubscribed).toHaveBeenCalledTimes(1)
    expect(selected.video.track!.attach).toHaveBeenCalledTimes(1)
    expect(selected.audio!.track!.attach).toHaveBeenCalledTimes(1)
    expect(selected.video.track!.detach).not.toHaveBeenCalled()
    expect(attachOutput).toHaveBeenCalledOnce()
  })

  it('rebinds elements without resubscribing or creating another audio output', () => {
    const selected = stream()
    const attachOutput = vi.fn(() => ({ dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }))
    const controller = new ScreenViewerController(() => [selected], { attach: attachOutput } as never)
    const firstVideo = {} as HTMLVideoElement
    const secondVideo = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement

    controller.select(selected.id, firstVideo, audio)
    controller.select(selected.id, secondVideo, audio)

    expect(selected.video.track!.detach).toHaveBeenCalledWith(firstVideo)
    expect(selected.video.track!.attach).toHaveBeenCalledWith(secondVideo)
    expect(selected.video.setSubscribed).toHaveBeenCalledTimes(1)
    expect(selected.audio!.setSubscribed).toHaveBeenCalledTimes(1)
    expect(attachOutput).toHaveBeenCalledOnce()
  })

  it('fails closed when a new publication reuses an id without confirmed session identity', () => {
    const original = stream()
    const replacement = stream(original.id)
    let current = original
    const controller = new ScreenViewerController(() => [current])
    const video = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement
    controller.select(original.id, video, audio)

    current = replacement
    controller.reconcile()

    expect(controller.selectedId).toBeNull()
    expect(controller.ended).toBe(true)
    expect(original.video.setSubscribed).toHaveBeenLastCalledWith(false)
    expect(replacement.video.setSubscribed).not.toHaveBeenCalledWith(true)
    expect(replacement.video.track!.attach).not.toHaveBeenCalled()

    controller.select(replacement.id, video, audio)
    expect(controller.selectedId).toBe(replacement.id)
    expect(replacement.video.setSubscribed).toHaveBeenLastCalledWith(true)
  })

  it('allows one explicit retry only while the selected publication remains current', () => {
    const selected = stream()
    let current: ScreenViewerStream[] = [selected]
    const controller = new ScreenViewerController(() => current)
    const video = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement
    controller.select(selected.id, video, audio)
    const operation = controller.operationGeneration

    expect(controller.retry()).toBe(true)
    expect(controller.operationGeneration).toBe(operation + 1)
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(2, false)
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(3, true)
    expect(selected.audio!.setSubscribed).toHaveBeenCalledTimes(1)
    expect(selected.audio!.track!.detach).not.toHaveBeenCalled()
    expect(controller.retry()).toBe(false)
    expect(selected.video.setSubscribed).toHaveBeenCalledTimes(3)

    current = []
    expect(controller.retry()).toBe(false)
    expect(controller.selectedId).toBeNull()
    expect(controller.ended).toBe(true)
    expect(selected.video.setSubscribed).toHaveBeenCalledTimes(4)
  })
})
