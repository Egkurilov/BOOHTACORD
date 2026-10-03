<script setup lang="ts">
import type { ChannelTopology, TopologyChannel } from './topology_client'
import { avatarBackground } from '../design/avatar_color'
import { avatarInitials } from '../design/avatar_initials'
import { nextTick, ref, watch } from 'vue'
import { useAuthorDirectory } from '../identity/author_directory'
import VoiceParticipantStatus from '../voice/VoiceParticipantStatus.vue'
import VoiceRoomRoster from '../voice/VoiceRoomRoster.vue'
import type { VoiceRoomRoster as RoomRoster } from '../voice/voice_roster_client'
import type { VoiceNavigationPresence } from './voice_navigation_presence'
import type { PermissionValues } from '../authorization/permission_keys'
import { categoryActions, channelActions } from './member_topology/action_resolver'
import { renameCategory } from './category_mutation_client'

const props = defineProps<{
  activeVoiceChannelId?: string
  selectedChannelId?: string
  topology: ChannelTopology
  voicePresence: VoiceNavigationPresence | null
  voiceRosters?: RoomRoster[] | null
  permissions?: PermissionValues
}>()

const emit = defineEmits<{
  select: [channel: TopologyChannel]
  createGlobal: []
  createInCategory: [category: ChannelTopology['categories'][number]]
  deleteCategory: [category: ChannelTopology['categories'][number]]
  deleteChannel: [channel: TopologyChannel]
  changed: []
}>()
const authors = useAuthorDirectory()
const categoryMenu = ref<{ x: number; y: number; category: ChannelTopology['categories'][number] } | null>(null)
const categoryMenuElement = ref<HTMLElement | null>(null)
const categoryMenuTrigger = ref<HTMLElement | null>(null)
const menuError = ref('')
watch(() => props.voicePresence?.members.map((member) => member.id) ?? [], (ids) => {
  ids.filter((id) => id !== 'self').forEach((id) => { void authors.ensure(id) })
}, { immediate: true })

function isConnectedVoice(channel: TopologyChannel): boolean { return channel.kind === 'VOICE' && channel.id === props.activeVoiceChannelId }
function rosterFor(channelId: string): RoomRoster | undefined { return props.voiceRosters?.find((room) => room.channelId === channelId) }
function canCreate(): boolean { return Boolean(props.permissions && (props.permissions['category.create'] || props.permissions['channel.text.create'] || props.permissions['channel.voice.create'])) }
function openCategoryMenu(event: MouseEvent, category: ChannelTopology['categories'][number]): void {
  if (!props.permissions) return
  categoryMenuTrigger.value = event.currentTarget as HTMLElement
  categoryMenu.value = { x: Math.max(8, Math.min(event.clientX, innerWidth - 276)), y: Math.max(8, Math.min(event.clientY, innerHeight - 267)), category }
  menuError.value = ''
  void nextTick(() => categoryMenuElement.value?.querySelector<HTMLElement>('button:not(:disabled)')?.focus())
}
function closeCategoryMenu(): void {
  categoryMenu.value = null
  void nextTick(() => categoryMenuTrigger.value?.focus())
}
async function renameFromMenu(): Promise<void> {
  const target = categoryMenu.value?.category
  if (!target || !props.permissions?.['category.create']) return
  const name = window.prompt('Новое название раздела', target.name)?.trim()
  if (!name) return
  try { await renameCategory(target.id, name, props.topology.revision); closeCategoryMenu(); emit('changed') }
  catch (cause) { menuError.value = cause instanceof Error ? cause.message : 'Не удалось переименовать раздел.' }
}
</script>

<template>
  <nav class="channel-navigation" aria-label="Категории и каналы">
    <div v-if="canCreate()" class="channel-navigation-actions"><span>Каналы</span><button type="button" aria-label="Создать категорию или канал" @click="emit('createGlobal')">+</button></div>
    <section v-for="category in props.topology.categories" :key="category.id" class="channel-category" @contextmenu.stop.prevent="openCategoryMenu($event, category)">
      <h2><span>{{ category.name }}</span><span v-if="props.permissions" class="channel-category-actions">
        <button v-if="categoryActions(props.permissions, category.channels.length === 0).createText || categoryActions(props.permissions, category.channels.length === 0).createVoice" type="button" :aria-label="`Создать канал в категории ${category.name}`" @click="emit('createInCategory', category)">+</button>
        <button v-if="categoryActions(props.permissions, category.channels.length === 0).delete" type="button" :aria-label="`Действия с категорией ${category.name}`" @click="emit('deleteCategory', category)">⋯</button>
      </span></h2>
      <p v-if="category.channels.length === 0" class="empty-category">Нет каналов</p>
      <template v-for="channel in category.channels" :key="channel.id">
        <div class="channel-row" @contextmenu.stop.prevent="props.permissions && channelActions(props.permissions, channel.kind).delete && emit('deleteChannel', channel)"><button
          class="channel-button"
          :class="{ selected: props.selectedChannelId === channel.id, 'voice-connected': isConnectedVoice(channel) }"
          :aria-current="props.selectedChannelId === channel.id ? 'page' : undefined"
          type="button"
          @click="emit('select', channel)"
        >
          <span class="channel-icon" aria-hidden="true">
            <template v-if="channel.kind === 'TEXT'">#</template>
            <svg v-else viewBox="0 0 24 24"><path d="m11 5-6 4H2v6h3l6 4V5ZM15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14" /></svg>
          </span>
          <span class="channel-name">{{ channel.name }}</span>
          <span v-if="channel.kind === 'TEXT' && channel.unreadCount" class="channel-state" :aria-label="`Непрочитанных сообщений: ${channel.unreadCount}`">{{ channel.unreadCount }}</span>
          <span v-if="channel.kind === 'TEXT' && channel.mentionCount" class="channel-state" :aria-label="`Упоминаний: ${channel.mentionCount}`">@{{ channel.mentionCount }}</span>
          <span v-if="channel.kind === 'VOICE' && (props.voicePresence?.channelId === channel.id ? props.voicePresence.memberCount > 0 : (rosterFor(channel.id)?.participants.length ?? 0) > 0)" class="channel-member-count" :title="`Участников в голосовом канале: ${props.voicePresence?.channelId === channel.id ? props.voicePresence.memberCount : rosterFor(channel.id)?.participants.length}`">{{ props.voicePresence?.channelId === channel.id ? props.voicePresence.memberCount : rosterFor(channel.id)?.participants.length }}</span>
          <span v-if="channel.admissionClosed" class="channel-state">Вход закрыт</span>
        </button><button v-if="props.permissions && channelActions(props.permissions, channel.kind).delete" class="channel-actions-button" type="button" :aria-label="`Действия с каналом ${channel.name}`" @click.stop="emit('deleteChannel', channel)">⋯</button></div>
        <ul v-if="props.voicePresence && props.voicePresence.channelId === channel.id" class="voice-member-list" aria-label="Участники подключённого голосового канала" data-testid="voice-member-rows">
          <li v-for="member in props.voicePresence.members" :key="member.id" class="voice-member-row" :class="{ 'is-speaking': member.isSpeaking }">
            <span class="voice-member-avatar" :style="{ backgroundColor: avatarBackground(member.id) }" aria-hidden="true"><img v-if="authors.avatarUrl(member.id)" :src="authors.avatarUrl(member.id)" alt=""><template v-else>{{ avatarInitials(member.name) }}</template></span>
            <span class="voice-member-name">{{ member.name }}</span>
            <span v-if="member.screenSharing" class="voice-member-share" role="img" aria-label="Показывает экран" title="Показывает экран"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 5h16v11H4zM9 20h6m-3-4v4" /></svg></span>
            <VoiceParticipantStatus compact :microphone-muted="member.microphoneMuted" :microphone-unavailable="member.microphoneUnavailable" :speaking="member.speaking" />
          </li>
        </ul>
        <VoiceRoomRoster v-else-if="channel.kind === 'VOICE' && rosterFor(channel.id)?.participants.length" :roster="rosterFor(channel.id)!" compact />
        </template>
    </section>
    <div v-if="categoryMenu" ref="categoryMenuElement" class="category-context-menu" role="menu" :style="{ left: `${categoryMenu.x}px`, top: `${categoryMenu.y}px` }" @keydown.esc.stop.prevent="closeCategoryMenu">
      <span class="category-context-caption">Раздел «{{ categoryMenu.category.name }}»</span>
      <button v-if="canCreate()" type="button" role="menuitem" @click="emit('createInCategory', categoryMenu.category); closeCategoryMenu()"><span class="category-context-icon" aria-hidden="true">＋</span>Создать канал...</button>
      <button v-if="props.permissions?.['category.create']" type="button" role="menuitem" @click="emit('createGlobal'); closeCategoryMenu()"><span class="category-context-icon" aria-hidden="true">▱</span>Создать раздел...</button>
      <div class="category-context-separator" role="separator" />
      <button v-if="props.permissions?.['category.create']" type="button" role="menuitem" @click="renameFromMenu"><span class="category-context-icon" aria-hidden="true">✎</span>Переименовать раздел...</button>
      <button v-if="props.permissions?.['category.delete']" type="button" role="menuitem" :disabled="categoryMenu.category.channels.length > 0" @click="emit('deleteCategory', categoryMenu.category); closeCategoryMenu()"><span class="category-context-icon" aria-hidden="true">♜</span>Удалить раздел...</button>
      <p v-if="categoryMenu.category.channels.length > 0" class="category-context-hint">Сначала уберите каналы из раздела.</p>
      <p v-if="menuError" role="alert">{{ menuError }}</p>
    </div>
  </nav>
</template>
