<script setup lang="ts">
import type { ChannelTopology, TopologyChannel } from './topology_client'
import { avatarBackground } from '../design/avatar_color'
import { watch } from 'vue'
import { useAuthorDirectory } from '../identity/author_directory'
import VoiceParticipantStatus from '../voice/VoiceParticipantStatus.vue'
import VoiceRoomRoster from '../voice/VoiceRoomRoster.vue'
import type { VoiceRoomRoster as RoomRoster } from '../voice/voice_roster_client'
import type { VoiceNavigationPresence } from './voice_navigation_presence'

const props = defineProps<{
  activeVoiceChannelId?: string
  selectedChannelId?: string
  topology: ChannelTopology
  voicePresence: VoiceNavigationPresence | null
  voiceRosters?: RoomRoster[] | null
}>()

const emit = defineEmits<{ select: [channel: TopologyChannel] }>()
const authors = useAuthorDirectory()
watch(() => props.voicePresence?.members.map((member) => member.id) ?? [], (ids) => {
  ids.filter((id) => id !== 'self').forEach((id) => { void authors.ensure(id) })
}, { immediate: true })

function isConnectedVoice(channel: TopologyChannel): boolean { return channel.kind === 'VOICE' && channel.id === props.activeVoiceChannelId }
function rosterFor(channelId: string): RoomRoster | undefined { return props.voiceRosters?.find((room) => room.channelId === channelId) }
function initial(name: string): string { return Array.from(name.trim())[0]?.toLocaleUpperCase('ru-RU') || 'У' }
</script>

<template>
  <nav class="channel-navigation" aria-label="Категории и каналы">
    <section v-for="category in props.topology.categories" :key="category.id" class="channel-category">
      <h2>{{ category.name }}</h2>
      <p v-if="category.channels.length === 0" class="empty-category">Нет каналов</p>
      <template v-for="channel in category.channels" :key="channel.id">
        <button
          class="channel-button"
          :class="{ selected: props.selectedChannelId === channel.id, 'voice-connected': isConnectedVoice(channel) }"
          :aria-current="props.selectedChannelId === channel.id ? 'page' : undefined"
          type="button"
          @click="emit('select', channel)"
        >
          <span class="channel-icon" aria-hidden="true">
            <template v-if="channel.kind === 'TEXT'">#</template>
            <svg v-else viewBox="0 0 24 24"><path d="M8 10v4a4 4 0 0 0 8 0v-4M12 18v3M8 21h8M12 3a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z" /></svg>
          </span>
          <span class="channel-name">{{ channel.name }}</span>
          <span v-if="channel.kind === 'TEXT' && channel.unreadCount" class="channel-state" :aria-label="`Непрочитанных сообщений: ${channel.unreadCount}`">{{ channel.unreadCount }}</span>
          <span v-if="channel.kind === 'TEXT' && channel.mentionCount" class="channel-state" :aria-label="`Упоминаний: ${channel.mentionCount}`">@{{ channel.mentionCount }}</span>
          <span v-if="channel.kind === 'VOICE' && (props.voicePresence?.channelId === channel.id ? props.voicePresence.memberCount > 0 : (rosterFor(channel.id)?.participants.length ?? 0) > 0)" class="channel-member-count" :title="`Участников в голосовом канале: ${props.voicePresence?.channelId === channel.id ? props.voicePresence.memberCount : rosterFor(channel.id)?.participants.length}`">{{ props.voicePresence?.channelId === channel.id ? props.voicePresence.memberCount : rosterFor(channel.id)?.participants.length }}</span>
          <span v-if="channel.admissionClosed" class="channel-state">Вход закрыт</span>
        </button>
        <ul v-if="props.voicePresence && props.voicePresence.channelId === channel.id" class="voice-member-list" aria-label="Участники подключённого голосового канала" data-testid="voice-member-rows">
          <li v-for="member in props.voicePresence.members" :key="member.id" class="voice-member-row" :class="{ 'is-speaking': member.isSpeaking }">
            <span class="voice-member-avatar" :style="{ backgroundColor: avatarBackground(member.id) }" aria-hidden="true"><img v-if="authors.avatarUrl(member.id)" :src="authors.avatarUrl(member.id)" alt=""><template v-else>{{ initial(member.name) }}</template></span>
            <span class="voice-member-name">{{ member.name }}</span>
            <span v-if="member.screenSharing" class="voice-member-share" role="img" aria-label="Показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v11H4zM9 20h6m-3-4v4" /></svg></span>
            <VoiceParticipantStatus compact :microphone-muted="member.microphoneMuted" :microphone-unavailable="member.microphoneUnavailable" :speaking="member.speaking" />
          </li>
        </ul>
        <VoiceRoomRoster v-else-if="channel.kind === 'VOICE' && rosterFor(channel.id)?.participants.length" :roster="rosterFor(channel.id)!" compact />
      </template>
    </section>
  </nav>
</template>
