<script setup lang="ts">
import { computed } from 'vue'
import type { ScreenShareState, VoiceConnectionState } from './connection_store'
import type { ScreenProfile } from './livekit_gateway'
import type { ScreenDiagnostics } from './screen_diagnostics'
import type { ScreenViewerCard } from './screen_viewer_controller'
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'
import { voiceRoomSummary } from './voice_room_copy'
import ScreenDiagnosticsPanel from './ScreenDiagnosticsPanel.vue'
import VoiceParticipantVolumes from './VoiceParticipantVolumes.vue'
import VoiceRoomControls from './VoiceRoomControls.vue'

const props = defineProps<{ roomName: string; voiceState: VoiceConnectionState; screenState: ScreenShareState; screenError: string | null; screenDiagnostics: ScreenDiagnostics; screenProfile: ScreenProfile | null; selectedScreenProfile: ScreenProfile; screenViewerCards: ScreenViewerCard[]; voiceVolumeError: string | null; voiceVolumeParticipants: VoiceVolumeParticipant[]; selfName: string | null; selfDeafened: boolean; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean; selfSpeaking: boolean; toggleMicrophone: () => void; toggleDeafen: () => void }>()
const emit = defineEmits<{ startScreen: [profile: ScreenProfile]; stopScreen: []; setVolume: [id: string, volume: number]; watchScreen: [id: string]; leave: []; refreshScreen: [] }>()
const captureAvailable = screenCaptureSupported()
const captureMessage = screenCaptureUnavailableMessage()
const firstScreen = computed(() => props.screenViewerCards.find((screen) => !screen.isLocal))
</script>

<template>
  <div class="room-intro">
    <div class="room-intro-copy"><h3>{{ voiceState === 'RECONNECTING' ? 'Восстанавливаем связь' : 'Все в сборе' }}</h3><p>{{ voiceRoomSummary(voiceVolumeParticipants.length + 1, screenViewerCards.length) }}</p></div>
    <button v-if="screenState !== 'SHARING'" class="gc-button gc-button--primary" type="button" :disabled="!captureAvailable || screenState === 'STARTING'" :title="captureAvailable ? undefined : captureMessage" @click="emit('startScreen', selectedScreenProfile)">Показать экран</button>
    <button v-else class="gc-button gc-button--secondary" type="button" @click="emit('stopScreen')">Остановить показ</button>
  </div>
  <p v-if="!captureAvailable" class="state" role="status">{{ captureMessage }}</p>
  <p v-if="screenError" class="state state-error" role="alert">{{ screenError }}</p>
  <VoiceParticipantVolumes :error="voiceVolumeError" :participants="voiceVolumeParticipants" :screen-streams="screenViewerCards" :selected-screen-stream-id="null" :self-name="selfName" :self-deafened="selfDeafened" :self-microphone-muted="selfMicrophoneMuted" :self-microphone-unavailable="selfMicrophoneUnavailable" :self-speaking="selfSpeaking" @set-volume="(id, volume) => emit('setVolume', id, volume)" @watch-screen="emit('watchScreen', $event)" />
  <button v-if="firstScreen" class="room-watch-primary" type="button" @click="emit('watchScreen', firstScreen.id)"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 4h18v13H3zM8 21h8m-4-4v4"/></svg>Смотреть экран {{ firstScreen.participantName }}</button>
  <VoiceRoomControls :voice-state="voiceState" :screen-state="screenState" :selected-screen-profile="selectedScreenProfile" :microphone-muted="selfMicrophoneMuted" :deafened="selfDeafened" :toggle-microphone="toggleMicrophone" :toggle-deafen="toggleDeafen" @start-screen="emit('startScreen', $event)" @stop-screen="emit('stopScreen')" @leave="emit('leave')" />
  <p class="voice-room-hint">Микрофон и звук трансляции управляются отдельно.</p>
  <details v-if="screenState === 'SHARING'" class="voice-advanced"><summary>Параметры демонстрации</summary><ScreenDiagnosticsPanel :diagnostics="screenDiagnostics" :profile="screenProfile" @refresh="emit('refreshScreen')" /><button class="voice-join" type="button" @click="emit('startScreen', screenProfile ?? selectedScreenProfile)">Изменить качество и FPS</button></details>
</template>
