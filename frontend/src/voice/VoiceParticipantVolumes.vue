<script setup lang="ts">
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import { avatarBackground } from '../design/avatar_color'
import VoiceParticipantStatus from './VoiceParticipantStatus.vue'

defineProps<{ error: string | null; participants: VoiceVolumeParticipant[]; selfName: string | null; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean }>()
const emit = defineEmits<{ setVolume: [id: string, percent: number] }>()
function initial(name: string | null | undefined): string { return name?.trim().slice(0, 1).toLocaleUpperCase('ru-RU') || 'У' }
</script>

<template>
  <section class="voice-participant-volumes participant-grid" aria-label="Участники голосового канала" data-testid="voice-participants">
    <h3 class="gc-sr-only">Участники голосового канала</h3>
    <p v-if="error" class="state state-error participant-grid-message" role="status">{{ error }}</p>
    <p v-else-if="participants.length === 0" class="state participant-grid-message">Другие участники пока не подключены.</p>
    <article class="participant participant-self voice-participant-self" data-testid="participant-card">
      <span class="avatar lg" :style="{ backgroundColor: avatarBackground(selfName ?? 'Вы') }" aria-hidden="true">{{ initial(selfName ?? 'Вы') }}</span>
      <span class="participant-name">{{ selfName || 'Вы' }}</span>
      <VoiceParticipantStatus class="participant-status" :microphone-muted="selfMicrophoneMuted" :microphone-unavailable="selfMicrophoneUnavailable" />
      <span class="participant-you">Это вы</span>
    </article>
    <article v-for="participant in participants" :key="participant.id" class="participant" :class="{ talking: participant.speaking && !participant.microphoneMuted }" data-testid="participant-card">
      <details v-if="participant.accountId" class="participant-volume">
        <summary :aria-label="`Настройки громкости ${participant.name || 'участника'}`" title="Настройки участника">•••</summary>
        <label>Громкость · {{ participant.volume }}%<input :aria-label="`Громкость микрофона ${participant.name || 'участника'}`" type="range" min="0" max="200" step="1" :value="participant.volume" @input="emit('setVolume', participant.id, Number(($event.target as HTMLInputElement).value))"></label>
      </details>
      <span class="avatar lg" :style="{ backgroundColor: avatarBackground(participant.accountId ?? participant.id) }" aria-hidden="true">{{ initial(participant.name) }}</span>
      <span class="participant-name">{{ participant.name || 'Участник' }}</span>
      <VoiceParticipantStatus class="participant-status" :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
    </article>
  </section>
</template>
