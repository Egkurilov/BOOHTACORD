import { ref, type Ref } from 'vue'
import { endTracedOperation, startTracedOperation } from '../telemetry/client_tracing'

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
    const span = startTracedOperation('screen.view')
    let failed = false
    try {
      controller.select(id, video, audio)
      error.value = null
    } catch (cause) {
      failed = true
      error.value = cause instanceof Error ? cause.message : 'Не удалось выбрать демонстрацию.'
    } finally {
      endTracedOperation(span, 'screen.view', failed)
    }
  }

  function stop(): void {
    stopObserving?.()
    stopObserving = null
    controller?.clear()
    controller = null
    error.value = null
    sync()
  }

  function clear(): void {
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
