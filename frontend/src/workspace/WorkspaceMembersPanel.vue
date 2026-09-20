<script setup lang="ts">
import type { TopologyChannel } from '../channel/topology_client'
import type { VoiceVolumeParticipant } from '../voice/voice_volume_controls'

defineProps<{ activeVoiceChannel: TopologyChannel | null; participants: VoiceVolumeParticipant[] }>()

function initial(name: string | undefined): string {
  const letter = name?.trim().slice(0, 1)
  return letter ? letter.toLocaleUpperCase('ru-RU') : 'У'
}
</script>

<template>
  <aside class="members members-panel" aria-label="Участники" data-testid="members-panel">
    <h2 class="members-heading">Участники</h2>
    <p v-if="!activeVoiceChannel">Выберите голосовой канал, чтобы увидеть участников.</p>
    <template v-else>
      <p class="members-summary">Голосовой канал · {{ activeVoiceChannel.name }}</p>
      <p v-if="!participants.length">В голосовой комнате пока нет других участников.</p>
      <ul v-else class="member-list" aria-label="Участники голосового канала">
        <li v-for="participant in participants" :key="participant.id" class="member-card member">
          <span class="member-avatar avatar" aria-hidden="true">{{ initial(participant.name) }}</span>
          <span class="member-copy name"><span class="member-name">{{ participant.name || 'Участник' }}</span><small class="member-state">{{ participant.microphoneMuted ? 'Микрофон выключен' : 'Микрофон включён' }}</small></span>
          <span class="member-speaking" :class="{ active: participant.speaking }">{{ participant.speaking ? 'Говорит' : '' }}</span>
        </li>
      </ul>
    </template>
  </aside>
</template>
