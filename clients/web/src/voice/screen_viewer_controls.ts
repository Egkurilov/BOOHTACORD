import { ref, type Ref } from 'vue'
import { createViewObservation } from '../telemetry/observe_render/screen'

import type { ScreenViewerCard, ScreenViewerController } from './screen_viewer_controller'

export interface ScreenViewerSession {
  screenViewer(): ScreenViewerController | null
}

export function createScreenViewerControls(
  session: ScreenViewerSession,
  cards: Ref<ScreenViewerCard[]>,
  selectedId: Ref<string | null>,
  error: Ref<string | null>,
  ended: Ref<boolean>,
) {
  let controller: ScreenViewerController | null = null
  const observation = createViewObservation()
  let stopObserving: (() => void) | null = null
  const audioMuted = ref(false)

  function sync(): void {
    cards.value = controller?.cards() ?? []
    selectedId.value = controller?.selectedId ?? null
    ended.value = controller?.ended ?? false
    audioMuted.value = controller?.audioMuted ?? false
  }

  function start(): void {
    stopObserving?.()
    controller = session.screenViewer()
    stopObserving = controller?.onChange(sync) ?? null
    error.value = null
    sync()
  }

  function select(id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null): void {
    if (!controller) return
    try {
      controller.select(id, video, audio)
      observation.select(video, () => controller?.selectedId === id && controller.hasAttachedVideo(video),id)
      error.value = null
    } catch (cause) {
      observation.fail()
      error.value = cause instanceof Error ? cause.message : 'Не удалось выбрать демонстрацию.'
    }
  }

  function stop(): void {
    observation.stop()
    stopObserving?.()
    stopObserving = null
    controller?.clear()
    controller = null
    error.value = null
    sync()
  }

  function clear(): void {
    observation.stop()
    controller?.clear()
  }

  function toggleAudio(volume: number, setVolume: (percent: number) => void): void {
    if (!controller?.selectedId) return
    if (volume === 0) {
      setVolume(100)
      if (controller.audioMuted) controller.setAudioMuted(false)
      return
    }
    controller.setAudioMuted(!controller.audioMuted)
  }

  return { audioMuted, clear, select, start, stop, toggleAudio }
}
