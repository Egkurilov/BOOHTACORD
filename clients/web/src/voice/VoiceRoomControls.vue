<script setup lang="ts">
import type { VoiceConnectionState, ScreenShareState } from './connection_store'
import type { ScreenProfile } from './livekit_gateway'

const props = defineProps<{ voiceState: VoiceConnectionState; screenState: ScreenShareState; selectedScreenProfile: ScreenProfile; microphoneMuted: boolean; deafened: boolean; toggleMicrophone: () => void; toggleDeafen: () => void }>()
const emit = defineEmits<{ startScreen: [profile: ScreenProfile]; stopScreen: []; leave: [] }>()
</script>

<template>
  <div class="voice-room-controls" role="group" aria-label="Управление голосом">
    <button type="button" :aria-label="microphoneMuted ? 'Включить микрофон' : 'Выключить микрофон'" :aria-pressed="!microphoneMuted" :disabled="voiceState === 'LEAVING'" @click="props.toggleMicrophone"><svg viewBox="0 0 24 24" aria-hidden="true"><rect x="9" y="3" width="6" height="12" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3m-4 0h8"/></svg></button>
    <button type="button" :aria-label="deafened ? 'Включить звук' : 'Выключить звук'" :aria-pressed="!deafened" :disabled="voiceState === 'LEAVING'" @click="props.toggleDeafen"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 13v-2a9 9 0 0 1 18 0v2M3 13h4v7H5a2 2 0 0 1-2-2v-5Zm18 0h-4v7h2a2 2 0 0 0 2-2v-5Z"/></svg></button>
    <button type="button" :aria-label="screenState === 'SHARING' ? 'Остановить показ экрана' : 'Показать экран'" :disabled="voiceState === 'LEAVING' || screenState === 'STARTING'" @click="screenState === 'SHARING' ? emit('stopScreen') : emit('startScreen', selectedScreenProfile)"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4"/></svg></button>
    <button class="voice-room-controls__leave" type="button" aria-label="Выйти из голосового канала" :disabled="voiceState === 'LEAVING'" @click="emit('leave')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 15c4.8-4.3 13.2-4.3 18 0l-2 3-3-1.5v-2.2a13 13 0 0 0-8 0v2.2L5 18z"/></svg></button>
  </div>
</template>
