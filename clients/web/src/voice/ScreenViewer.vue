<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { avatarBackground, avatarForeground } from '../design/avatar_color'
import { participantAudioMessage, screenAudioMessage } from './screen_audio_copy'
import ScreenViewerAudioControl from './ScreenViewerAudioControl.vue'
import ScreenViewerRail from './ScreenViewerRail.vue'
import ScreenReceiverDiagnosticsPanel from './ScreenReceiverDiagnosticsPanel.vue'
import type { ScreenViewerCard } from './screen_viewer_controller'
import { createScreenFullscreenControls } from './screen_fullscreen_controls'
import { useScreenPlaybackQuality } from './screen_playback_quality'
import { useScreenReceiverDiagnostics } from './use_screen_receiver_diagnostics'
import { buildScreenClientReport, startScreenClientReporting, webPlatform } from './screen_client_reporter'
const props = defineProps<{ audioMuted: boolean; cards: ScreenViewerCard[]; deafened: boolean; ended: boolean; error: string | null; expanded: boolean; mini?: boolean; ownScreenSharing?: boolean; pinned?: boolean; participantCount: number; selectedAudioVolume: number; selectedId: string | null }>()
const emit = defineEmits<{ changeQuality: []; clear: []; pin: []; returnVoice: []; select: [id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null]; setAudioVolume: [percent: number]; toggleAudio: []; 'update:expanded': [expanded: boolean] }>()
const video = ref<HTMLVideoElement | null>(null)
const audio = ref<HTMLAudioElement | null>(null)
const stage = ref<HTMLDivElement | null>(null)
const moreActions = ref<HTMLDetailsElement | null>(null)
const fullscreenActive = ref(false)
const fullscreenFeedback = ref('')
const { actualVideoQuality, markVideoReady, playbackFps, refreshVideoQuality, resetVideoFrame, videoReady } = useScreenPlaybackQuality(video, () => props.selectedId, () => props.ended)
let fullscreenControls: ReturnType<typeof createScreenFullscreenControls> | null = null
let stopReporting: (() => void) | null = null
const selectedStream = computed(() => props.cards.find((stream) => stream.id === props.selectedId) ?? null)
const { metrics: receiverMetrics, sampledAt: receiverSampledAt } = useScreenReceiverDiagnostics(selectedStream, () => props.ended)
const adjustable = computed(() => Boolean(selectedStream.value?.hasAudio && selectedStream.value.accountId && !selectedStream.value.isLocal))
const audioMessage = computed(() => selectedStream.value ? screenAudioMessage({
  isLocal: Boolean(selectedStream.value.isLocal), hasAudio: selectedStream.value.hasAudio,
  adjustable: adjustable.value, deafened: props.deafened,
}) : '')
function select(id: string): void { emit('select', id, video.value, audio.value) }
function changeQuality(): void { if (moreActions.value) moreActions.value.open = false; emit('changeQuality') }
function selectStream(id: string): void { select(id) }
defineExpose({ selectStream })
function handleKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape' && props.expanded) emit('update:expanded', false)
}
onMounted(() => {
  fullscreenControls = createScreenFullscreenControls(() => stage.value, document, (active) => { fullscreenActive.value = active })
  const platform = webPlatform(navigator.userAgent)
  stopReporting = startScreenClientReporting(() => buildScreenClientReport({
    platform, selected: Boolean(selectedStream.value && !selectedStream.value.isLocal && !props.ended),
    hasTrack: Boolean(selectedStream.value?.readReceiverStats), videoReady: videoReady.value,
    playbackFps: playbackFps.value, receiverMetrics: receiverMetrics.value,
    sampledAt: receiverSampledAt.value ?? undefined,
    frameWidth: video.value?.videoWidth, frameHeight: video.value?.videoHeight,
  }), () => document.visibilityState === 'visible')
  window.addEventListener('keydown', handleKeydown)
})
onBeforeUnmount(() => {
  stopReporting?.()
  fullscreenControls?.dispose()
  window.removeEventListener('keydown', handleKeydown)
  if (props.expanded) emit('update:expanded', false)
  emit('clear')
})
async function toggleFullscreen(): Promise<void> {
  fullscreenFeedback.value = ''
  try {
    const available = await fullscreenControls?.toggle()
    if (!available) fullscreenFeedback.value = 'Полноэкранный режим недоступен в этом браузере.'
  } catch {
    fullscreenFeedback.value = 'Не удалось развернуть демонстрацию на весь экран.'
  }
}
</script>
<template>
  <section class="screen-viewer stream-wrap" aria-label="Демонстрация экрана">
      <div v-if="mini && selectedStream" class="screen-mini-toolbar">
        <strong>{{ selectedStream.participantName || 'Демонстрация' }}</strong>
        <button type="button" @click="emit('returnVoice')">К голосу</button>
        <button v-if="selectedStream.hasAudio && !selectedStream.isLocal" type="button" :aria-pressed="!audioMuted" @click="emit('toggleAudio')">{{ audioMuted ? 'Включить звук' : 'Выключить звук' }}</button>
        <button type="button" @click="emit('clear')">Остановить просмотр</button>
      </div>
      <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
      <div ref="stage" class="screen-stage" :class="{ 'screen-stage--waiting': !selectedStream }">
      <p v-if="ended" class="state" role="status">Демонстрация завершена. Выберите другую вручную или вернитесь к участникам.</p>
      <p v-else-if="selectedStream && !videoReady" class="state screen-loading-state" role="status">Получаем первый кадр демонстрации…</p>
      <p v-else-if="!selectedId && cards.length === 0" class="state">Участники пока не показывают экран.</p>
      <p v-else-if="!selectedId" class="state">Выберите демонстрацию. Загружается только один выбранный поток.</p>
      <video ref="video" v-show="selectedId" class="screen-player" autoplay playsinline :muted="selectedStream?.isLocal ?? false" aria-label="Выбранная демонстрация" @loadedmetadata="refreshVideoQuality" @resize="refreshVideoQuality" @loadeddata="markVideoReady" @emptied="resetVideoFrame"></video>
      <template v-if="selectedStream">
        <div class="screen-stage-top">
          <span class="screen-stage-label"><span class="screen-stage-avatar" :style="{ backgroundColor: avatarBackground(selectedStream.accountId ?? selectedStream.participantId), color: avatarForeground(selectedStream.accountId ?? selectedStream.participantId) }" aria-hidden="true">{{ selectedStream.participantName.slice(0, 2).toLocaleUpperCase('ru-RU') }}</span>{{ selectedStream.isLocal ? 'Ваш экран' : `Экран ${selectedStream.participantName || 'участника'}` }}<b>ЭФИР</b></span>
        </div>
      </template>
      <p v-if="fullscreenFeedback" class="screen-fullscreen-feedback" role="status" aria-live="polite">{{ fullscreenFeedback }}</p>
    </div>
    <audio ref="audio" autoplay></audio>
    <div v-if="selectedStream" class="stream-quality-row">
      <ScreenViewerAudioControl v-if="selectedStream.hasAudio && !selectedStream.isLocal" :adjustable="adjustable" :deafened="deafened" :muted="audioMuted" :volume="selectedAudioVolume" @toggle="emit('toggleAudio')" @set-volume="emit('setAudioVolume', $event)" />
      <p v-if="audioMessage" class="stream-audio-status gc-sr-only" role="status">{{ audioMessage }}</p>
      <div class="stream-toolbar-actions">
        <button type="button" class="stream-tool-button" :aria-label="pinned ? 'Открепить просмотр' : 'Закрепить просмотр'" :aria-pressed="Boolean(pinned)" @click="emit('pin')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m16 3 5 5-4 2-3 5-2 1-4-4 1-2 5-3 2-4ZM8 16l-5 5"/></svg></button>
        <ScreenReceiverDiagnosticsPanel :actual-video-quality="actualVideoQuality" :has-audio="selectedStream.hasAudio" :is-local="Boolean(selectedStream.isLocal)" :metrics="receiverMetrics" :sampled-at="receiverSampledAt" :target-profile="selectedStream.targetProfile" :participant-name="selectedStream.participantName" :presented-fps="playbackFps" />
        <button class="screen-fullscreen-button stream-tool-button" type="button" :aria-label="fullscreenActive ? 'Выйти из полноэкранного режима' : 'Развернуть демонстрацию на весь экран'" :aria-pressed="fullscreenActive" :title="fullscreenActive ? 'Выйти из полноэкранного режима' : 'Развернуть демонстрацию на весь экран'" @click="toggleFullscreen"><svg viewBox="0 0 24 24" aria-hidden="true"><path v-if="fullscreenActive" d="M9 3v6H3M15 3v6h6M3 15h6v6M21 15h-6v6" /><path v-else d="M8 3H3v5M16 3h5v5M3 16v5h5M21 16v5h-5" /></svg></button>
        <details ref="moreActions" class="stream-more-actions"><summary class="stream-tool-button" aria-label="Дополнительные действия"><svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="5" cy="12" r="1"/><circle cx="12" cy="12" r="1"/><circle cx="19" cy="12" r="1"/></svg></summary><div class="stream-voice-return"><p class="gc-sr-only">{{ participantAudioMessage(deafened) }}</p><button v-if="ownScreenSharing" type="button" @click="changeQuality">Качество трансляции</button><button type="button" @click="emit('update:expanded', !expanded)">{{ expanded ? 'Вернуть в окно канала' : 'Развернуть на всю область' }}</button><button type="button" @click="emit('clear')">К участникам</button></div></details>
      </div>
    </div>
    <ScreenViewerRail v-if="cards.length" :cards="cards" :selected-id="selectedId" :participant-count="participantCount" @select="select" @return-voice="emit('returnVoice')" />
  </section>
</template>
