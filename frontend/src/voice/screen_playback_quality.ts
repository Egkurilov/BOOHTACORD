import { onBeforeUnmount, ref, watch, type Ref } from 'vue'

import { observeScreenPlaybackFps } from './screen_playback_fps'
import { formatScreenVideoQuality } from './screen_video_quality'

export function useScreenPlaybackQuality(video: Ref<HTMLVideoElement | null>, selectedId: () => string | null, ended: () => boolean) {
  const actualVideoQuality = ref('Определяем качество…')
  const playbackFps = ref<number | null>(null)
  const videoReady = ref(false)
  let stopObservingPlayback: (() => void) | null = null

  function refreshVideoQuality(): void {
    actualVideoQuality.value = formatScreenVideoQuality(videoReady.value ? video.value : null, playbackFps.value)
  }

  function restartPlaybackObservation(): void {
    stopObservingPlayback?.()
    stopObservingPlayback = null
    playbackFps.value = null
    videoReady.value = false
    refreshVideoQuality()
    if (video.value && selectedId() && !ended()) {
      stopObservingPlayback = observeScreenPlaybackFps(video.value, (fps) => {
        playbackFps.value = fps
        refreshVideoQuality()
      }, () => {
        videoReady.value = true
        refreshVideoQuality()
      })
    }
  }

  function markVideoReady(): void {
    videoReady.value = Boolean(video.value?.videoWidth && video.value?.videoHeight)
    refreshVideoQuality()
  }

  watch([video, selectedId, ended], restartPlaybackObservation, { flush: 'post' })
  onBeforeUnmount(() => stopObservingPlayback?.())
  return { actualVideoQuality, markVideoReady, refreshVideoQuality, resetVideoFrame: restartPlaybackObservation, videoReady }
}
