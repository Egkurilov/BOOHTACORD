<script setup lang="ts">
import type { VoiceVolumeParticipant } from './voice_volume_controls'

defineProps<{ error: string | null; participants: VoiceVolumeParticipant[] }>()
const emit = defineEmits<{ setVolume: [id: string, percent: number] }>()

function initial(name: string | undefined): string {
  return name?.trim().slice(0, 1).toLocaleUpperCase('ru-RU') || 'У'
}
</script>

<template>
  <section class="voice-participant-volumes participant-grid" aria-label="Громкость участников">
    <h3 class="gc-sr-only">Участники голосового канала</h3>
    <p v-if="error" class="state state-error" role="status">{{ error }}</p>
    <p v-else-if="participants.length === 0" class="state">В голосовой комнате пока нет других участников.</p>
    <article v-for="participant in participants" :key="participant.id" class="participant" :class="{ talking: participant.speaking }">
      <span class="avatar lg" aria-hidden="true">{{ initial(participant.name) }}</span>
      <span class="participant-name">{{ participant.name || 'Участник' }}</span>
      <span class="participant-status" :class="{ talking: participant.speaking }" role="status">{{ participant.speaking ? 'Говорит' : participant.microphoneMuted ? 'Микрофон выключен' : 'В канале' }}</span>
      <details v-if="participant.accountId" class="participant-volume"><summary>Громкость · {{ participant.volume }}%</summary><input :aria-label="`Громкость микрофона ${participant.name || 'участника'}`" type="range" min="0" max="200" step="1" :value="participant.volume" @input="emit('setVolume', participant.id, Number(($event.target as HTMLInputElement).value))"></details>
      <small v-else>Громкость недоступна.</small>
    </article>
  </section>
</template>
