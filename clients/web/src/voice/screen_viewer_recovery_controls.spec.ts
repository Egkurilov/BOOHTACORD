import { ref } from 'vue'
import { describe, expect, it, vi } from 'vitest'

import { createScreenViewerControls } from './screen_viewer_controls'
import { ScreenViewerController, type ScreenViewerStream } from './screen_viewer_controller'
import { bindLiveKitScreenViewer } from './livekit_screen_viewer_adapter'

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

describe('screen viewer recovery controls', () => {
  it('limits explicit recovery to one video-only retry', () => {
    const selected = stream()
    const controller = new ScreenViewerController(() => [selected])
    const error = ref<string | null>(null)
    const controls = createScreenViewerControls({ screenViewer: () => controller }, ref([]), ref<string | null>(null), error, ref(false))
    controls.start()
    controls.select(selected.id, {} as HTMLVideoElement, {} as HTMLAudioElement)

    expect(controls.retry()).toBe(true)
    expect(controls.retry()).toBe(false)
    expect(error.value).toContain('Выберите её снова')
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(2, false)
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(3, true)
    expect(selected.audio!.setSubscribed).toHaveBeenCalledTimes(1)
  })

  it('surfaces only a current selected track subscription failure', () => {
    const selected = stream()
    selected.video.trackSid = 'TR_current'
    const controller = new ScreenViewerController(() => [selected])
    const error = ref<string | null>(null)
    const controls = createScreenViewerControls({ screenViewer: () => controller }, ref([]), ref<string | null>(null), error, ref(false))
    controls.start()
    controls.select(selected.id, null, null)

    expect(controller.markSubscriptionFailed('TR_stale', 'alice')).toBe(false)
    expect(error.value).toBeNull()
    expect(controller.markSubscriptionFailed('TR_current', 'alice')).toBe(true)
    expect(error.value).toBe('Не удалось подписаться на демонстрацию.')
  })

  it('allows one automatic video retry per publication generation and keeps manual recovery available', () => {
    const selected = stream()
    const controller = new ScreenViewerController(() => [selected])
    const controls = createScreenViewerControls({ screenViewer: () => controller }, ref([]), ref<string | null>(null), ref<string | null>(null), ref(false))
    const video = {} as HTMLVideoElement
    controls.start()
    controls.select(selected.id, video, {} as HTMLAudioElement)

    expect(controls.retry(true)).toBe(true)
    expect(controls.retry(true)).toBe(false)
    expect(controls.retry()).toBe(true)
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(2, false)
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(3, true)
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(4, false)
    expect(selected.video.setSubscribed).toHaveBeenNthCalledWith(5, true)
    expect(selected.audio!.setSubscribed).toHaveBeenCalledTimes(1)

    controls.clear()
    controls.select(selected.id, video, {} as HTMLAudioElement)
    expect(controls.retry(true)).toBe(false)
    expect(selected.video.setSubscribed).toHaveBeenLastCalledWith(true)
    controls.stop()
  })

  it('clears failure only for the selected publication when LiveKit confirms subscription', () => {
    const video = { source: 'screen-video', trackSid: 'TR_current', setSubscribed: vi.fn() }
    const alice = { identity: 'alice', getTrackPublication: (source: string) => source === 'screen-video' ? video : undefined }
    const listeners = new Map<string, Array<(...arguments_: any[]) => void>>()
    const room = { on: vi.fn((event: string, listener: (...arguments_: any[]) => void) => listeners.set(event, [...(listeners.get(event) ?? []), listener])), remoteParticipants: new Map([['alice', alice]]) }
    const dispatch = (event: string, ...arguments_: any[]) => listeners.get(event)?.forEach((listener) => listener(...arguments_))
    const binding = bindLiveKitScreenViewer(room, {
      activeSpeakersChanged: 'active-speakers-changed', participantConnected: 'participant-connected', participantDisconnected: 'participant-disconnected', localTrackPublished: 'local-track-published', localTrackUnpublished: 'local-track-unpublished', trackMuted: 'track-muted', trackPublished: 'track-published', trackSubscribed: 'track-subscribed', trackSubscriptionFailed: 'track-subscription-failed', trackUnmuted: 'track-unmuted', trackUnpublished: 'track-unpublished', trackUnsubscribed: 'track-unsubscribed',
    }, { microphone: 'microphone', screenAudio: 'screen-audio', screenVideo: 'screen-video' })
    binding.refresh()
    binding.viewer.select('alice:screen', null, null)
    dispatch('track-subscription-failed', 'TR_current', alice)
    expect(binding.viewer.subscriptionFailed).toBe(true)
    dispatch('track-subscribed', {}, { ...video, trackSid: 'TR_stale' }, alice)
    expect(binding.viewer.subscriptionFailed).toBe(true)
    dispatch('track-subscribed', {}, video, alice)
    expect(binding.viewer.subscriptionFailed).toBe(false)
  })
})
