import { ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { createScreenViewerControls } from './screen_viewer_controls'
import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'
import type { ScreenViewerCard } from './screen_viewer_controller'

function stream(id = 'alice:screen', hasAudio = true): ScreenViewerStream {
  return {
    hasAudio,
    id,
    participantId: id.split(':')[0],
    participantName: 'Alice',
    audio: hasAudio ? { setSubscribed: vi.fn(), track: { attach: vi.fn(), detach: vi.fn() } } : undefined,
    video: { setSubscribed: vi.fn(), track: { attach: vi.fn(), detach: vi.fn() } },
  }
}

describe('screen viewer selection controls', () => {
  it('exposes ended state and waits for explicit selection instead of auto-playing the next stream', () => {
    const alice = stream('alice', false)
    const bob = stream('bob', false)
    const streams = [alice, bob]
    const controller = new ScreenViewerController(() => streams)
    const cards = ref<ScreenViewerCard[]>([])
    const selectedId = ref<string | null>(null)
    const error = ref<string | null>(null)
    const ended = ref(false)
    const controls = createScreenViewerControls({ screenViewer: () => controller }, cards, selectedId, error, ended)

    controls.start()
    controls.select('alice', null, null)
    streams.splice(0, 1)
    controller.reconcile()

    expect(selectedId.value).toBeNull()
    expect(ended.value).toBe(true)
    expect(cards.value.map((card) => card.id)).toEqual(['bob'])
    expect(bob.video.setSubscribed).not.toHaveBeenCalled()

    controls.clear()
    expect(selectedId.value).toBeNull()
    expect(ended.value).toBe(false)
    expect(cards.value.map((card) => card.id)).toEqual(['bob'])
    streams.push(stream('charlie'))
    controller.reconcile()
    expect(cards.value.map((card) => card.id)).toEqual(['bob', 'charlie'])

    controls.select('bob', null, null)
    expect(selectedId.value).toBe('bob')
    expect(ended.value).toBe(false)
    controls.stop()
    expect(ended.value).toBe(false)
  })

  it('clears a removed selected stream without automatically choosing another one', () => {
    const source: ScreenViewerStream[] = [stream()]
    const controller = new ScreenViewerController(() => source)
    const cards = ref<ScreenViewerCard[]>([])
    const error = ref<string | null>(null)
    const selectedId = ref<string | null>(null)
    const controls = createScreenViewerControls({ screenViewer: () => controller }, cards, selectedId, error, ref(false))

    controls.start()
    controls.select('alice:screen', {} as HTMLVideoElement, {} as HTMLAudioElement)
    source.splice(0)
    controller.reconcile()

    expect(cards.value).toEqual([])
    expect(selectedId.value).toBeNull()
    expect(error.value).toBeNull()
    expect(controller.selectedId).toBeNull()
  })

  it('clears selected media and stops observing the room on leave', () => {
    const selected = stream()
    const output = { dispose: vi.fn(), setMuted: vi.fn(), setVolume: vi.fn() }
    const controller = new ScreenViewerController(() => [selected], { attach: vi.fn(() => output) } as never)
    const controls = createScreenViewerControls(
      { screenViewer: () => controller }, ref<ScreenViewerCard[]>([]), ref<string | null>(null), ref<string | null>(null), ref(false),
    )

    controls.start()
    controls.select('alice:screen', {} as HTMLVideoElement, {} as HTMLAudioElement)
    controls.stop()

    expect(controller.selectedId).toBeNull()
    expect(selected.video.setSubscribed).toHaveBeenLastCalledWith(false)
    expect(selected.audio!.setSubscribed).toHaveBeenLastCalledWith(false)
    expect(output.dispose).toHaveBeenCalledOnce()
  })

  it('routes recovery through one explicit video-only retry and reports an exhausted attempt', () => {
    const selected = stream()
    const controller = new ScreenViewerController(() => [selected])
    const error = ref<string | null>(null)
    const controls = createScreenViewerControls({ screenViewer: () => controller }, ref<ScreenViewerCard[]>([]), ref<string | null>(null), error, ref(false))
    controls.start()
    controls.select(selected.id, {} as HTMLVideoElement, {} as HTMLAudioElement)

    expect(controls.retry()).toBe(true)
    expect(controls.retry()).toBe(false)
    expect(error.value).toContain('Выберите её снова')
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(2, false)
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(3, true)
    expect(selected.audio!.setSubscribed).toHaveBeenCalledTimes(1)
  })

  it('surfaces the SDK subscription failure for the current viewer', () => {
    const selected = stream()
    selected.video.trackSid = 'TR_current'
    const controller = new ScreenViewerController(() => [selected])
    const error = ref<string | null>(null)
    const controls = createScreenViewerControls({ screenViewer: () => controller }, ref<ScreenViewerCard[]>([]), ref<string | null>(null), error, ref(false))
    controls.start()
    controls.select(selected.id, null, null)

    expect(controller.markSubscriptionFailed('TR_stale', 'alice')).toBe(false)
    expect(error.value).toBeNull()
    expect(controller.markSubscriptionFailed('TR_current', 'alice')).toBe(true)
    expect(error.value).toBe('Не удалось подписаться на демонстрацию.')
  })
})
