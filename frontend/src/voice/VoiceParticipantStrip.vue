<script setup lang="ts">
import type { VoiceVolumeParticipant } from './voice_volume_controls'
import VoiceParticipantStatus from './VoiceParticipantStatus.vue'

defineProps<{ error: string | null; participants: VoiceVolumeParticipant[] }>()

function initial(name: string | undefined): string {
  return name?.trim().slice(0, 1).toLocaleUpperCase('ru-RU') || 'У'
}
</script>

<template>
  <section class="voice-participant-strip" aria-label="Другие участники голосового канала">
    <h3>Другие в голосе <span>{{ participants.length }}</span></h3>
    <p v-if="error" class="state state-error" role="status">{{ error }}</p>
    <p v-else-if="participants.length === 0" class="state">Другие участники пока не подключены.</p>
    <ul v-else>
      <li v-for="participant in participants" :key="participant.id" :class="{ 'is-speaking': participant.speaking }">
        <span class="voice-strip-avatar" aria-hidden="true">{{ initial(participant.name) }}</span>
        <span class="voice-strip-name">{{ participant.name || 'Участник' }}</span>
        <VoiceParticipantStatus :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
      </li>
    </ul>
  </section>
</template>
