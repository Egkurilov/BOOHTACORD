<script setup lang="ts">
import { computed, nextTick, ref } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import type { VoiceVolumeParticipant } from '../voice/voice_volume_controls'
import VoiceParticipantStatus from '../voice/VoiceParticipantStatus.vue'
import MemberPopover from './MemberPopover.vue'

const props = defineProps<{ activeVoiceChannel: TopologyChannel | null; selectedVoiceChannel: TopologyChannel | null; participants: VoiceVolumeParticipant[]; role: 'MEMBER' | 'ADMINISTRATOR'; accountID?: string; selfMicrophoneMuted: boolean; selfMicrophoneUnavailable: boolean; selfName: string | null }>()
const emit = defineEmits<{ openDM: [userID: string]; setVolume: [participantID: string, volume: number] }>()
const selectedID = ref<string | null>(null); const popoverTop = ref(80); const trigger = ref<HTMLButtonElement | null>(null)
const selected = computed(() => props.participants.find((participant) => participant.accountId === selectedID.value) ?? null)
const visibleVoiceChannel = computed(() => props.activeVoiceChannel ?? props.selectedVoiceChannel)
function openProfile(participant: VoiceVolumeParticipant, event: MouseEvent): void {
  if (!participant.accountId) return
  const button = event.currentTarget as HTMLButtonElement
  trigger.value = button
  popoverTop.value = Math.max(64, button.getBoundingClientRect().top - button.closest('.members')!.getBoundingClientRect().top)
  selectedID.value = participant.accountId
}
function closeProfile(): void { selectedID.value = null; void nextTick(() => trigger.value?.focus()) }
function setVolume(volume: number): void { if (selected.value) emit('setVolume', selected.value.id, volume) }

function initial(name: string | undefined): string {
  const letter = name?.trim().slice(0, 1)
  return letter ? letter.toLocaleUpperCase('ru-RU') : 'У'
}
</script>

<template>
  <aside class="members members-panel" aria-label="Участники" data-testid="members-panel">
    <h2 class="members-heading">Участники <span>{{ activeVoiceChannel ? participants.length + 1 : '—' }}</span></h2>
    <p v-if="!visibleVoiceChannel">Выберите голосовой канал, чтобы увидеть участников.</p>
    <template v-else>
      <p class="members-summary">Голосовой канал · {{ visibleVoiceChannel.name }}</p>
      <p v-if="!activeVoiceChannel" class="members-empty">Подключитесь к каналу, чтобы увидеть его участников.</p>
      <ul v-else class="member-list" aria-label="Участники голосового канала">
        <li class="member-card member member-self">
          <span class="member-avatar avatar" aria-hidden="true">{{ initial(selfName ?? 'Вы') }}</span>
          <span class="member-copy name"><span class="member-name">{{ selfName || 'Вы' }}</span><small class="member-state">Вы</small></span>
          <VoiceParticipantStatus compact :microphone-muted="selfMicrophoneMuted" :microphone-unavailable="selfMicrophoneUnavailable" />
        </li>
        <li v-if="!participants.length" class="members-empty">Других участников пока нет.</li>
        <li v-for="participant in participants" :key="participant.id">
          <button class="member-card member" :class="{ 'member-speaking': participant.speaking }" type="button" :disabled="!participant.accountId" :aria-label="`Профиль: ${participant.name || 'Участник'}`" @click="openProfile(participant, $event)">
            <span class="member-avatar avatar" aria-hidden="true">{{ initial(participant.name) }}</span>
            <span class="member-copy name"><span class="member-name">{{ participant.name || 'Участник' }}</span><small class="member-state">В голосе</small></span>
            <VoiceParticipantStatus compact :microphone-muted="participant.microphoneMuted" :speaking="participant.speaking" />
          </button>
        </li>
      </ul>
    </template>
    <MemberPopover v-if="selected && selected.accountId" :member-i-d="selected.accountId" :self="selected.accountId === props.accountID" :viewer-role="props.role" :same-voice="Boolean(activeVoiceChannel)" :volume="selected.volume" :top="popoverTop" @close="closeProfile" @open-d-m="emit('openDM', $event)" @set-volume="setVolume" />
  </aside>
</template>
