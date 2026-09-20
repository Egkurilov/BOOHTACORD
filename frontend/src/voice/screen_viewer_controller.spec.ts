import { describe, expect, it, vi } from 'vitest'

import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'

function stream(id: string, hasAudio = true, calls: string[] = []): ScreenViewerStream {
  return {
    hasAudio,
    id,
    participantId: id,
    participantName: id.toUpperCase(),
    audio: hasAudio ? { setSubscribed: vi.fn((subscribed: boolean) => calls.push(`${id}:audio:${subscribed}`)), track: { attach: vi.fn(), detach: vi.fn() } } : undefined,
    video: { setSubscribed: vi.fn((subscribed: boolean) => calls.push(`${id}:video:${subscribed}`)), track: { attach: vi.fn(), detach: vi.fn() } },
  }
}

describe('screen viewer controller', () => {
  it('detaches and unsubscribes the old screen before subscribing to the selected one', () => {
    const calls: string[] = []
    const old = stream('alice', true, calls)
    const next = stream('bob', true, calls)
    const controller = new ScreenViewerController(() => [old, next])
    const video = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement

    controller.select('alice', video, audio)
    vi.clearAllMocks()
    calls.splice(0)
    controller.select('bob', video, audio)

    expect(old.video.track!.detach).toHaveBeenCalledWith(video)
    expect(old.audio!.track!.detach).toHaveBeenCalledWith(audio)
    expect(old.video.setSubscribed).toHaveBeenCalledWith(false)
    expect(old.audio!.setSubscribed).toHaveBeenCalledWith(false)
    expect(next.video.setSubscribed).toHaveBeenCalledWith(true)
    expect(next.audio!.setSubscribed).toHaveBeenCalledWith(true)
    expect(calls.indexOf('alice:video:false')).toBeLessThan(calls.indexOf('bob:video:true'))
    expect(calls.indexOf('alice:audio:false')).toBeLessThan(calls.indexOf('bob:audio:true'))
    expect(controller.selectedId).toBe('bob')
  })

  it('clears the selection when the selected remote stream disappears', () => {
    const selected = stream('alice')
    const streams: ScreenViewerStream[] = [selected]
    const controller = new ScreenViewerController(() => streams)
    const video = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement

    controller.select('alice', video, audio)
    streams.splice(0)
    controller.reconcile()

    expect(controller.selectedId).toBeNull()
    expect(selected.video.setSubscribed).toHaveBeenLastCalledWith(false)
    expect(selected.audio!.setSubscribed).toHaveBeenLastCalledWith(false)
  })

  it('rejects a stream not reported by the current room', () => {
    const controller = new ScreenViewerController(() => [])

    expect(() => controller.select('not-in-room', {} as HTMLVideoElement, {} as HTMLAudioElement)).toThrow('Недоступная демонстрация')
  })

  it('mutes the one selected screen-audio element while deafened', () => {
    const selected = stream('alice')
    const controller = new ScreenViewerController(() => [selected])
    const audio = { muted: false } as HTMLAudioElement

    controller.select('alice', {} as HTMLVideoElement, audio)
    controller.setDeafened(true)

    expect(audio.muted).toBe(true)
    controller.setDeafened(false)
    expect(audio.muted).toBe(false)
  })

  it('sets a separate selected-stream audio level and disposes it when switching streams', () => {
    const first = stream('alice')
    const second = stream('bob')
    const firstOutput = { dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }
    const secondOutput = { dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }
    const outputs = [firstOutput, secondOutput]
    const controller = new ScreenViewerController(() => [first, second], { attach: vi.fn(() => outputs.shift()!) } as never)
    const audio = {} as HTMLAudioElement

    controller.select('alice', {} as HTMLVideoElement, audio)
    controller.setAudioVolume(160)
    controller.select('bob', {} as HTMLVideoElement, audio)

    expect(firstOutput.setVolume).toHaveBeenCalledWith(160)
    expect(firstOutput.dispose).toHaveBeenCalledOnce()
    expect(secondOutput.setVolume).toHaveBeenCalledWith(160)
  })
})
