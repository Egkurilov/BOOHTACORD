<script setup lang="ts">
defineProps<{ adjustable: boolean; deafened: boolean; muted: boolean; volume: number }>()
const emit = defineEmits<{ toggle: []; setVolume: [percent: number] }>()
</script>

<template>
  <button class="gc-button gc-button--secondary screen-audio-toggle" type="button" :aria-label="muted || volume === 0 ? 'Включить звук трансляции' : 'Выключить звук трансляции'" :aria-pressed="!muted && volume > 0" :disabled="deafened" @click="emit('toggle')">{{ muted || volume === 0 ? 'Включить звук' : 'Выключить звук' }}</button>
  <label v-if="adjustable" class="volume-control">
    <span>Громкость аудиодорожки · {{ volume }}%</span>
    <input aria-label="Громкость звука выбранной демонстрации" type="range" min="0" max="200" step="1" :value="volume" @input="emit('setVolume', Number(($event.target as HTMLInputElement).value))">
  </label>
</template>
