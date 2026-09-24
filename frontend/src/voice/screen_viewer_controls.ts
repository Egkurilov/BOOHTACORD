import type { Ref } from 'vue'

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

  function sync(): void {
    cards.value = controller?.cards() ?? []
    selectedId.value = controller?.selectedId ?? null
    ended.value = controller?.ended ?? false
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
      error.value = null
    } catch (cause) {
      error.value = cause instanceof Error ? cause.message : 'Не удалось выбрать демонстрацию.'
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

  return { clear, select, start, stop }
}
