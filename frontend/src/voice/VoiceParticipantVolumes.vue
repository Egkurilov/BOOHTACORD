<script setup lang="ts">
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import { avatarBackground } from '../design/avatar_color'
import { findParticipantScreen } from './find_participant_screen'
import type { ScreenViewerCard } from './screen_viewer_controller'
import VoiceParticipantStatus from './VoiceParticipantStatus.vue'

const props = defineProps<{ error: string | null; participants: VoiceVolumeParticipant[]; screenStreams: ScreenViewerCard[]; selectedScreenStreamId: string | null; selfName: string | null; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean; selfSpeaking: boolean }>()
const emit = defineEmits<{ setVolume: [id: string, percent: number]; watchScreen: [id: string] }>()
function initial(name: string | null | undefined): string { return name?.trim().slice(0, 1).toLocaleUpperCase('ru-RU') || 'У' }
function selfDisplayName(name: string | null): string { return name ? `${name} · вы` : 'Вы' }
function screenForParticipant(participantId: string): ScreenViewerCard | null { return findParticipantScreen(props.screenStreams, participantId) }
function watchParticipantScreen(participantId: string): void { const screen = screenForParticipant(participantId); if (screen) emit('watchScreen', screen.id) }
</script>

<template>
  <section class="voice-participant-volumes participant-grid" aria-label="Участники голосового канала" data-testid="voice-participants">
    <h3 class="gc-sr-only">Участники голосового канала</h3>
    <p v-if="error" class="state state-error participant-grid-message" role="status">{{ error }}</p>
    <p v-else-if="participants.length === 0" class="state participant-grid-message">Другие участники пока не подключены.</p>
    <article class="participant participant-self voice-participant-self" :class="{ talking: selfSpeaking && !selfMicrophoneMuted && !selfMicrophoneUnavailable }" data-testid="participant-card">
      <span class="avatar lg" :style="{ backgroundColor: avatarBackground(selfName ?? 'Вы') }" aria-hidden="true">{{ initial(selfName ?? 'Вы') }}</span>
      <span class="participant-name">{{ selfDisplayName(selfName) }}</span>
      <VoiceParticipantStatus class="participant-status" :microphone-muted="selfMicrophoneMuted" :microphone-unavailable="selfMicrophoneUnavailable" :speaking="selfSpeaking" />
    </article>
    <article v-for="participant in participants" :key="participant.id" class="participant" :class="{ talking: participant.speaking && !participant.microphoneMuted }" data-testid="participant-card">
      <details v-if="participant.accountId" class="participant-volume">
        <summary :aria-label="`Настройки громкости ${participant.name || 'участника'}`" title="Настройки участника">•••</summary>
        <label>Громкость · {{ participant.volume }}%<input :aria-label="`Громкость микрофона ${participant.name || 'участника'}`" type="range" min="0" max="200" step="1" :value="participant.volume" @input="emit('setVolume', participant.id, Number(($event.target as HTMLInputElement).value))"></label>
      </details>
      <span class="avatar lg" :style="{ backgroundColor: avatarBackground(participant.accountId ?? participant.id) }" aria-hidden="true">{{ initial(participant.name) }}</span>
      <span class="participant-name">{{ participant.name || 'Участник' }}</span>
      <VoiceParticipantStatus class="participant-status" :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
      <span v-if="screenForParticipant(participant.id)" class="participant-share-badge" aria-label="Участник показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v11H4zM9 20h6m-3-4v4" /></svg></span>
      <button v-if="screenForParticipant(participant.id)" class="participant-watch" type="button" :aria-pressed="screenForParticipant(participant.id)?.id === selectedScreenStreamId" @click="watchParticipantScreen(participant.id)">Смотреть экран</button>
    </article>
  </section>
</template>
