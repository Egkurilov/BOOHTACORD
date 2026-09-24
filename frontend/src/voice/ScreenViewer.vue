<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

import type { ScreenViewerCard } from './screen_viewer_controller'
import { createScreenFullscreenControls } from './screen_fullscreen_controls'

const props = defineProps<{ cards: ScreenViewerCard[]; error: string | null; expanded: boolean; selectedAudioVolume: number; selectedId: string | null }>()
const emit = defineEmits<{ clear: []; select: [id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null]; setAudioVolume: [percent: number]; 'update:expanded': [expanded: boolean] }>()
const video = ref<HTMLVideoElement | null>(null)
const audio = ref<HTMLAudioElement | null>(null)
const stage = ref<HTMLDivElement | null>(null)
const fullscreenActive = ref(false)
const fullscreenFeedback = ref('')
let fullscreenControls: ReturnType<typeof createScreenFullscreenControls> | null = null
const selectedStream = computed(() => props.cards.find((stream) => stream.id === props.selectedId) ?? null)

function select(id: string): void {
  emit('select', id, video.value, audio.value)
}

function handleKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape' && props.expanded) emit('update:expanded', false)
}

onMounted(() => {
  fullscreenControls = createScreenFullscreenControls(() => stage.value, document, (active) => { fullscreenActive.value = active })
  window.addEventListener('keydown', handleKeydown)
})
onBeforeUnmount(() => {
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
  <section class="screen-viewer stream-wrap" aria-label="Демонстрации участников">
    <div class="stream-meta"><h3>Демонстрации в голосовом канале</h3><span v-if="selectedStream">{{ selectedStream.participantName }} · экран</span></div>
    <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
    <div ref="stage" class="screen-stage">
      <p v-if="!selectedId && cards.length === 0" class="state">Участники пока не показывают экран.</p>
      <p v-else-if="!selectedId" class="state">Выберите одну демонстрацию. Остальные не загружают видео или звук.</p>
      <video ref="video" v-show="selectedId" class="screen-player" autoplay playsinline aria-label="Выбранная демонстрация"></video>
      <button v-if="selectedId" class="screen-fullscreen-button" type="button" :aria-label="fullscreenActive ? 'Выйти из полноэкранного режима' : 'Развернуть демонстрацию на весь экран'" :aria-pressed="fullscreenActive" :title="fullscreenActive ? 'Выйти из полноэкранного режима' : 'Развернуть демонстрацию на весь экран'" @click="toggleFullscreen">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path v-if="fullscreenActive" d="M9 3v6H3M15 3v6h6M3 15h6v6M21 15h-6v6" /><path v-else d="M3 9V3h6M15 3h6v6M21 15v6h-6M9 21H3v-6" /></svg>
      </button>
      <p v-if="fullscreenFeedback" class="screen-fullscreen-feedback" role="status" aria-live="polite">{{ fullscreenFeedback }}</p>
    </div>
    <audio ref="audio" autoplay></audio>
    <div class="stream-controls">
      <label v-if="selectedStream?.hasAudio && selectedStream.accountId" class="volume-control">
        <span>Игра · {{ selectedAudioVolume }}%</span>
        <input aria-label="Громкость звука выбранной демонстрации" type="range" min="0" max="200" step="1" :value="selectedAudioVolume" @input="emit('setAudioVolume', Number(($event.target as HTMLInputElement).value))">
      </label>
      <button v-if="selectedId" class="voice-leave" type="button" @click="emit('clear')">Прекратить просмотр</button>
      <button v-if="selectedId" class="screen-window-toggle gc-button gc-button--secondary" type="button" :aria-pressed="expanded" @click="emit('update:expanded', !expanded)">{{ expanded ? 'Вернуть в окно канала' : 'Развернуть на всю область' }}</button>
    </div>
    <div v-if="cards.length" class="screen-cards stream-rail" aria-label="Выбор демонстрации">
      <button v-for="stream in cards" :key="stream.id" class="screen-card stream-option" :class="{ selected: stream.id === selectedId }" type="button" @click="select(stream.id)">
        <span>{{ stream.participantName }}</span><small>{{ stream.hasAudio ? 'со звуком' : 'без аудио' }}</small>
      </button>
    </div>
  </section>
</template>
