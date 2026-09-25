<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'

import { avatarBackground } from '../design/avatar_color'
import { participantAudioMessage, screenAudioMessage } from './screen_audio_copy'
import type { ScreenViewerCard } from './screen_viewer_controller'
import { createScreenFullscreenControls } from './screen_fullscreen_controls'
import { useScreenPlaybackQuality } from './screen_playback_quality'
import { observeHorizontalOverflow } from './screen_rail_overflow'

const props = defineProps<{ cards: ScreenViewerCard[]; deafened: boolean; ended: boolean; error: string | null; expanded: boolean; selectedAudioVolume: number; selectedId: string | null }>()
const emit = defineEmits<{ clear: []; select: [id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null]; setAudioVolume: [percent: number]; 'update:expanded': [expanded: boolean] }>()
const video = ref<HTMLVideoElement | null>(null)
const audio = ref<HTMLAudioElement | null>(null)
const stage = ref<HTMLDivElement | null>(null)
const fullscreenActive = ref(false)
const fullscreenFeedback = ref('')
const { actualVideoQuality, markVideoReady, refreshVideoQuality, resetVideoFrame, videoReady } = useScreenPlaybackQuality(video, () => props.selectedId, () => props.ended)
const rail = ref<HTMLDivElement | null>(null)
const railHasOverflow = ref(false)
let stopObservingRail: (() => void) | null = null
let fullscreenControls: ReturnType<typeof createScreenFullscreenControls> | null = null
const selectedStream = computed(() => props.cards.find((stream) => stream.id === props.selectedId) ?? null)
const adjustable = computed(() => Boolean(selectedStream.value?.hasAudio && selectedStream.value.accountId && !selectedStream.value.isLocal))
const audioMessage = computed(() => selectedStream.value ? screenAudioMessage({
  isLocal: Boolean(selectedStream.value.isLocal), hasAudio: selectedStream.value.hasAudio,
  adjustable: adjustable.value, deafened: props.deafened,
}) : '')
watch(rail, (element) => {
  stopObservingRail?.()
  stopObservingRail = element ? observeHorizontalOverflow(element, (visible) => { railHasOverflow.value = visible }) : null
}, { flush: 'post' })

function select(id: string): void {
  emit('select', id, video.value, audio.value)
}
function selectStream(id: string): void { select(id) }
function streamInitial(stream: ScreenViewerCard): string { return Array.from(stream.participantName.trim())[0]?.toLocaleUpperCase('ru-RU') || 'У' }
defineExpose({ selectStream })

function handleKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape' && props.expanded) emit('update:expanded', false)
}

onMounted(() => {
  fullscreenControls = createScreenFullscreenControls(() => stage.value, document, (active) => { fullscreenActive.value = active })
  window.addEventListener('keydown', handleKeydown)
})
onBeforeUnmount(() => {
  stopObservingRail?.()
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
      <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
      <div ref="stage" class="screen-stage" :class="{ 'screen-stage--waiting': !selectedStream }">
      <p v-if="ended" class="state" role="status">Демонстрация завершена. Выберите другую вручную или вернитесь к участникам.</p>
      <p v-else-if="selectedStream && !videoReady" class="state screen-loading-state" role="status">Получаем первый кадр демонстрации…</p>
      <p v-else-if="!selectedId && cards.length === 0" class="state">Участники пока не показывают экран.</p>
      <p v-else-if="!selectedId" class="state">Выберите демонстрацию. Загружается только один выбранный поток.</p>
      <video ref="video" v-show="selectedId" class="screen-player" autoplay playsinline :muted="selectedStream?.isLocal ?? false" aria-label="Выбранная демонстрация" @loadedmetadata="refreshVideoQuality" @resize="refreshVideoQuality" @loadeddata="markVideoReady" @emptied="resetVideoFrame"></video>
      <template v-if="selectedStream">
        <div class="screen-stage-top">
          <span class="screen-stage-label"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v11H4zM9 20h6m-3-4v4" /></svg>{{ selectedStream.isLocal ? 'Предпросмотр' : 'Смотрите экран' }}</span>
          <span class="screen-publisher-name">{{ selectedStream.isLocal ? 'Ваш экран' : (selectedStream.participantName || 'Участник') }}</span>
        </div>
        <button class="screen-fullscreen-button" type="button" :aria-label="fullscreenActive ? 'Выйти из полноэкранного режима' : 'Развернуть демонстрацию на весь экран'" :aria-pressed="fullscreenActive" :title="fullscreenActive ? 'Выйти из полноэкранного режима' : 'Развернуть демонстрацию на весь экран'" @click="toggleFullscreen">
          <svg viewBox="0 0 24 24" aria-hidden="true"><path v-if="fullscreenActive" d="M9 3v6H3M15 3v6h6M3 15h6v6M21 15h-6v6" /><path v-else d="M3 9V3h6M15 3h6v6M21 15v6h-6M9 21H3v-6" /></svg>
        </button>
      </template>
      <p v-if="fullscreenFeedback" class="screen-fullscreen-feedback" role="status" aria-live="polite">{{ fullscreenFeedback }}</p>
    </div>
    <audio ref="audio" autoplay></audio>
    <div v-if="selectedStream" class="stream-quality-row">
      <div class="stream-quality"><span class="stream-target">Цель: не передана источником</span><span class="stream-actual">Сейчас: {{ actualVideoQuality }}</span></div>
      <details class="stream-diagnostics">
        <summary title="Нет свежих данных"><span class="stream-diagnostics-badge" aria-hidden="true"></span><span class="gc-sr-only">Нет свежих данных</span></summary>
        <div class="stream-diagnostics-panel"><dl>
          <div><dt>Целевой профиль</dt><dd>Не передан источником</dd></div>
          <div><dt>Текущее разрешение</dt><dd>{{ actualVideoQuality }}</dd></div>
          <div><dt>Качество связи</dt><dd>Нет свежих данных</dd></div>
          <div><dt>Аудиодорожка</dt><dd>{{ selectedStream.isLocal ? 'Предпросмотр без звука' : selectedStream.hasAudio ? 'Аудиодорожка есть' : 'Аудиодорожки нет' }}</dd></div>
          <div><dt>Последнее измерение</dt><dd>Нет свежих данных</dd></div>
        </dl></div>
      </details>
      <label v-if="adjustable" class="volume-control">
        <span>Громкость аудиодорожки · {{ selectedAudioVolume }}%</span>
        <input aria-label="Громкость звука выбранной демонстрации" type="range" min="0" max="200" step="1" :value="selectedAudioVolume" @input="emit('setAudioVolume', Number(($event.target as HTMLInputElement).value))">
      </label>
      <p v-if="audioMessage" class="stream-audio-status" role="status">{{ audioMessage }}</p>
    </div>
      <div v-if="cards.length" class="screen-rail-section">
        <h3>Демонстрации в канале</h3>
        <div ref="rail" class="screen-cards stream-rail" :class="{ 'has-overflow': railHasOverflow }" data-testid="stream-rail" aria-label="Выбор демонстрации" :aria-description="railHasOverflow ? 'Есть ещё демонстрации справа. Прокрутите список по горизонтали.' : undefined">
          <button v-for="stream in cards" :key="stream.id" data-testid="stream-select" class="screen-card stream-option" :class="{ selected: stream.id === selectedId }" type="button" :aria-pressed="stream.id === selectedId" @click="select(stream.id)">
          <span class="stream-avatar" :style="{ backgroundColor: avatarBackground(stream.accountId ?? stream.participantId) }" aria-hidden="true">{{ streamInitial(stream) }}</span>
          <span class="stream-option-copy"><span>{{ stream.isLocal ? 'Ваш экран' : (stream.participantName || 'Участник') }}</span><small>{{ stream.id === selectedId ? 'Вы смотрите' : 'Нажмите, чтобы смотреть' }}</small><span class="gc-sr-only">{{ stream.isLocal ? 'Собственный экран без звука' : stream.hasAudio ? 'Звуковая дорожка есть' : 'Звуковой дорожки нет' }}</span></span>
          <svg class="stream-audio-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 9v6h4l5 4V5L7 9H3Z" /><path v-if="stream.hasAudio" d="M16 9a4 4 0 0 1 0 6m2.5-8.5a8 8 0 0 1 0 11" /><path v-else d="m16 9 5 6m0-6-5 6" /></svg>
          <span v-if="stream.id === selectedId" class="stream-selected-marker" aria-hidden="true">✓</span>
        </button>
      </div>
    </div>
    <div v-if="selectedStream || ended" class="stream-voice-return"><div class="stream-voice-return-copy"><p>{{ participantAudioMessage(deafened) }}</p><small>Невыбранные демонстрации не воспроизводятся</small></div><button v-if="selectedStream || expanded" class="screen-window-toggle gc-button gc-button--secondary" type="button" :aria-pressed="expanded" @click="emit('update:expanded', !expanded)">{{ expanded ? 'Вернуть в окно канала' : 'Развернуть на всю область' }}</button><button class="gc-button gc-button--secondary" type="button" @click="emit('clear')">К участникам</button></div>
  </section>
</template>
