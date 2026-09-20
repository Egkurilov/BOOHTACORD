<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'

import type { ScreenViewerCard } from './screen_viewer_controller'

const props = defineProps<{ cards: ScreenViewerCard[]; error: string | null; selectedAudioVolume: number; selectedId: string | null }>()
const emit = defineEmits<{ clear: []; select: [id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null]; setAudioVolume: [percent: number] }>()
const video = ref<HTMLVideoElement | null>(null)
const audio = ref<HTMLAudioElement | null>(null)
const selectedStream = computed(() => props.cards.find((stream) => stream.id === props.selectedId) ?? null)

function select(id: string): void {
  emit('select', id, video.value, audio.value)
}

onBeforeUnmount(() => emit('clear'))
</script>

<template>
  <section class="screen-viewer stream-wrap" aria-label="Демонстрации участников">
    <div class="stream-meta"><h3>Демонстрации в голосовом канале</h3><span v-if="selectedStream">{{ selectedStream.participantName }} · экран</span></div>
    <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
    <div class="screen-stage">
      <p v-if="!selectedId && cards.length === 0" class="state">Участники пока не показывают экран.</p>
      <p v-else-if="!selectedId" class="state">Выберите одну демонстрацию. Остальные не загружают видео или звук.</p>
      <video ref="video" v-show="selectedId" class="screen-player" autoplay playsinline aria-label="Выбранная демонстрация"></video>
    </div>
    <audio ref="audio" autoplay></audio>
    <div class="stream-controls">
      <label v-if="selectedStream?.hasAudio && selectedStream.accountId" class="volume-control">
        <span>Игра · {{ selectedAudioVolume }}%</span>
        <input aria-label="Громкость звука выбранной демонстрации" type="range" min="0" max="200" step="1" :value="selectedAudioVolume" @input="emit('setAudioVolume', Number(($event.target as HTMLInputElement).value))">
      </label>
      <button v-if="selectedId" class="voice-leave" type="button" @click="emit('clear')">Прекратить просмотр</button>
    </div>
    <div v-if="cards.length" class="screen-cards stream-rail" aria-label="Выбор демонстрации">
      <button v-for="stream in cards" :key="stream.id" class="screen-card stream-option" :class="{ selected: stream.id === selectedId }" type="button" @click="select(stream.id)">
        <span>{{ stream.participantName }}</span><small>{{ stream.hasAudio ? 'со звуком' : 'без аудио' }}</small>
      </button>
    </div>
  </section>
</template>
