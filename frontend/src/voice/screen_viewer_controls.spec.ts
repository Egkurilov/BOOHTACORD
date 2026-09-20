import { ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'
import { createScreenViewerControls } from './screen_viewer_controls'

function stream(): ScreenViewerStream {
  return {
    hasAudio: true,
    id: 'alice:screen',
    participantId: 'alice',
    participantName: 'Alice',
    audio: { setSubscribed: vi.fn(), track: { attach: vi.fn(), detach: vi.fn() } },
    video: { setSubscribed: vi.fn(), track: { attach: vi.fn(), detach: vi.fn() } },
  }
}

describe('screen viewer controls', () => {
  it('clears a removed selected stream and never chooses another one automatically', () => {
    const source: ScreenViewerStream[] = [stream()]
    const controller = new ScreenViewerController(() => source)
    const cards = ref([])
    const error = ref<string | null>(null)
    const selectedId = ref<string | null>(null)
    const controls = createScreenViewerControls({ screenViewer: () => controller }, cards, selectedId, error)
    const video = {} as HTMLVideoElement
    const audio = {} as HTMLAudioElement

    controls.start()
    controls.select('alice:screen', video, audio)
    source.splice(0)
    controller.reconcile()

    expect(cards.value).toEqual([])
    expect(selectedId.value).toBeNull()
    expect(error.value).toBeNull()
    expect(controller.selectedId).toBeNull()
  })

  it('clears media and stops observing the room on leave', () => {
    const selected = stream()
    const controller = new ScreenViewerController(() => [selected])
    const controls = createScreenViewerControls({ screenViewer: () => controller }, ref([]), ref<string | null>(null), ref<string | null>(null))

    controls.start()
    controls.select('alice:screen', {} as HTMLVideoElement, {} as HTMLAudioElement)
    controls.stop()

    expect(controller.selectedId).toBeNull()
    expect(selected.video.setSubscribed).toHaveBeenLastCalledWith(false)
    expect(selected.audio!.setSubscribed).toHaveBeenLastCalledWith(false)
  })
})
