<script setup lang="ts">
defineProps<{ adjustable: boolean; deafened: boolean; muted: boolean; volume: number }>()
const emit = defineEmits<{ toggle: []; setVolume: [percent: number] }>()
</script>

<template>
  <button class="screen-audio-toggle stream-tool-button" type="button" :aria-label="muted || volume === 0 ? 'Включить звук трансляции' : 'Выключить звук трансляции'" :aria-pressed="!muted && volume > 0" :disabled="deafened" @click="emit('toggle')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 9v6h4l5 4V5L7 9H3Zm12 1a4 4 0 0 1 0 4m2-7a8 8 0 0 1 0 10"/></svg></button>
  <label v-if="adjustable" class="volume-control">
    <span class="gc-sr-only">Громкость аудиодорожки · {{ volume }}%</span>
    <input aria-label="Громкость звука выбранной демонстрации" type="range" min="0" max="200" step="1" :value="volume" @input="emit('setVolume', Number(($event.target as HTMLInputElement).value))">
    <output>{{ volume }}%</output>
  </label>
</template>
