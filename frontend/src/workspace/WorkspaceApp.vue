<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import ChannelNavigation from '../channel/ChannelNavigation.vue'
import { buildVoiceNavigationPresence } from '../channel/voice_navigation_presence'
import { createVoiceRosterRealtime } from '../voice/voice_roster_realtime'
import type { TopologyChannel } from '../channel/topology_client'
import DirectMessageNavigation from '../direct_message/DirectMessageNavigation.vue'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import { useDirectMessageCandidateStore } from '../direct_message/direct_message_candidate_store'
import VoiceDock from '../voice/VoiceDock.vue'
import ScreenShareSetupDialog from '../voice/ScreenShareSetupDialog.vue'
import type { ScreenProfile } from '../voice/livekit_gateway'
import AudioSettings from '../voice/AudioSettings.vue'
import { useMessageStore } from '../conversation/message_store'
import { useRealtimeStore } from '../realtime/realtime_store'
import { createWorkspaceRealtime } from './workspace_realtime'
import { bindWorkspaceLogout } from './logout_flow'
import { expireWorkspaceSession } from './session_expiry_media'
import { useWorkspaceVoiceControls } from './voice_controls'
import WorkspaceMain from './WorkspaceMain.vue'
import WorkspaceMembersPanel from './WorkspaceMembersPanel.vue'
import WorkspaceSidebarTabs from './WorkspaceSidebarTabs.vue'
import WorkspaceUserFooter from './WorkspaceUserFooter.vue'
import { useGuildPresence } from '../identity/guild_presence'
import { useWorkspaceDrawers } from './useWorkspaceDrawers'
import ProfileSettings from '../identity/ProfileSettings.vue'
import { useCurrentProfile } from '../identity/current_profile'
import { useAuthorDirectoryLifecycle } from '../identity/author_directory_lifecycle'
import AdminPanel from './AdminPanel.vue'
import SearchLauncher from '../search/SearchLauncher.vue'
import WorkspaceSearchPanel from '../search/WorkspaceSearchPanel.vue'
import { useMemberHeaderExpanded } from './member_header_expanded'
const props = defineProps<{ role: 'MEMBER' | 'ADMINISTRATOR'; accountId: string }>()
const emit = defineEmits<{ sessionExpired: []; loggedOut: [] }>()
const { activeVoiceChannel, audioSettings, joinVoice, leaveVoice, selectAudioDevice, selectedChannel, selectedChannelId, selectChannel: selectWorkspaceChannel, selectDirectMessage: selectWorkspaceDirectMessage, startScreen, topologyStore, voiceActivation, voiceConnection } = useWorkspaceVoiceControls()
const selectedScreenProfile = ref<ScreenProfile>('P1080_30')
const screenShareSetupOpen = ref(false)
const directMessageStore = useDirectMessageStore()
const directMessageCandidateStore = useDirectMessageCandidateStore()
const messageStore = useMessageStore()
const realtimeStore = useRealtimeStore(), voiceRoster = createVoiceRosterRealtime()
const { busy: logoutBusy, error: logoutError, signOut } = bindWorkspaceLogout(voiceConnection, leaveVoice, realtimeStore, () => emit('loggedOut'))
const guildPresence = useGuildPresence()
const workspaceRealtime = createWorkspaceRealtime({ topology: topologyStore, messages: messageStore, directMessages: directMessageStore }, realtimeStore, guildPresence, voiceConnection, props.accountId, () => expireWorkspaceSession(voiceConnection, () => emit('sessionExpired')))
watch(() => realtimeStore.state, (state) => { if (state === 'ERROR' || state === 'DISCONNECTED') guildPresence.invalidate(); if (state === 'CONNECTED') voiceRoster.reconnect() })
const sidebarSection = ref<'channels' | 'messages'>('channels')
const activePanel = ref<'none' | 'admin' | 'audio' | 'profile' | 'search'>('none')
const { navOpen, membersOpen, modalDrawer, closeDrawers, toggleNavigation, toggleMembers } = useWorkspaceDrawers(activePanel)
const { profile, profileError, profileLoading, refreshProfile, setProfile } = useCurrentProfile()
useAuthorDirectoryLifecycle(profile)
const selectedDirectMessage = computed(() => directMessageStore.directMessages.find((item) => item.id === directMessageStore.directMessageId) ?? null)
const voiceStageWide = computed(() => selectedChannel.value?.kind === 'VOICE' && !selectedDirectMessage.value && activePanel.value === 'none')
const memberHeaderExpandedState = useMemberHeaderExpanded(voiceStageWide, membersOpen, closeDrawers)
const voiceNavigationPresence = computed(() => buildVoiceNavigationPresence(activeVoiceChannel.value?.id ?? null, profile.value, voiceConnection))
function selectChannel(channel: TopologyChannel): void { closeDrawers(); activePanel.value = 'none'; sidebarSection.value = 'channels'; directMessageStore.close(); selectWorkspaceChannel(channel) }
function returnToVoice(channelId: string): void { const channel = topologyStore.topology?.categories.flatMap(({ channels }) => channels).find(({ id, kind }) => id === channelId && kind === 'VOICE'); if (channel) selectChannel(channel) }
function selectDirectMessage(directMessageId: string): void { closeDrawers(); activePanel.value = 'none'; sidebarSection.value = 'messages'; selectWorkspaceDirectMessage(directMessageId); void directMessageStore.open(directMessageId) }
async function selectOpenedDirectMessage(directMessageId: string): Promise<void> { await directMessageStore.refreshNavigation(); selectDirectMessage(directMessageId) }
async function openDirectMessageFromMember(userID: string): Promise<void> {
  activePanel.value = 'none'; sidebarSection.value = 'messages'; directMessageStore.close()
  const directMessageID = await directMessageCandidateStore.open(userID)
  if (directMessageID) await selectOpenedDirectMessage(directMessageID)
  else directMessageStore.error = directMessageCandidateStore.error ?? 'Не удалось открыть личное сообщение.'
}
function setParticipantVolume(participantID: string, volume: number): void { voiceConnection.setParticipantVolume(participantID, volume) }
function openScreenShareSetup(profile = selectedScreenProfile.value): void {
  if (voiceConnection.screenState === 'STARTING' || voiceConnection.screenState === 'STOPPING') return
  selectedScreenProfile.value = profile
  screenShareSetupOpen.value = true
}
function confirmScreenShare(profile: ScreenProfile): void {
  selectedScreenProfile.value = profile
  screenShareSetupOpen.value = false
  void startScreen(profile)
}
function refreshTopology(): void { void topologyStore.refresh() }
function togglePanel(panel: 'admin' | 'audio' | 'profile' | 'search'): void { closeDrawers(); activePanel.value = activePanel.value === panel ? 'none' : panel }
function openGuildPanel(): void { if (props.role === 'ADMINISTRATOR') togglePanel('admin') }
onMounted(() => { void topologyStore.refresh(); void directMessageStore.refreshNavigation(); void refreshProfile(); voiceRoster.start(); workspaceRealtime.start() }); onBeforeUnmount(() => { voiceRoster.stop(); workspaceRealtime.stop() })
</script>
<template>
  <div class="app-frame">
    <a class="gc-sr-only" href="#main-region">Перейти к содержимому</a>
      <div class="gc-shell" :class="{ 'no-aside': (activePanel === 'search' && voiceStageWide) || (activePanel !== 'search' && (voiceStageWide || selectedDirectMessage || activePanel !== 'none')), 'search-active': activePanel === 'search', 'voice-stage-wide': voiceStageWide, 'members-collapsed': membersOpen && !voiceStageWide && !selectedDirectMessage && activePanel === 'none' }" data-testid="app-shell">
      <aside id="nav-sidebar" class="sidebar" :class="{ 'is-open': navOpen }" :role="modalDrawer === 'nav' ? 'dialog' : undefined" :aria-modal="modalDrawer === 'nav' ? 'true' : undefined" aria-label="Навигация гильдии" data-testid="nav-sidebar">
        <div class="nav-drawer" tabindex="-1">
          <button class="guild-header" type="button" :aria-expanded="activePanel === 'admin'" @click="openGuildPanel"><span class="guild-mark" aria-hidden="true">G</span><span id="app-title">Моя гильдия</span></button><SearchLauncher :active="activePanel === 'search'" @open="togglePanel('search')" @close="activePanel = 'none'" />
          <WorkspaceSidebarTabs class="sidebar-tabs" :active="sidebarSection" @select="sidebarSection = $event" />
          <div class="nav-content">
          <template v-if="sidebarSection === 'channels'">
            <p v-if="topologyStore.loading" class="state" aria-live="polite">Загружаем каналы…</p>
            <p v-else-if="topologyStore.error" class="state state-error" role="alert">{{ topologyStore.error }} Войдите в аккаунт или повторите попытку.</p>
            <template v-else-if="topologyStore.topology">
              <ChannelNavigation :active-voice-channel-id="activeVoiceChannel?.id" :selected-channel-id="selectedChannelId ?? undefined" :topology="topologyStore.topology" :voice-presence="voiceNavigationPresence" :voice-rosters="voiceRoster.channels.value" @select="selectChannel" />
            </template>
            <p v-else class="state">Каналы пока не созданы.</p>
          </template>
          <DirectMessageNavigation
            v-else
            :direct-messages="directMessageStore.directMessages"
            :error="directMessageStore.error"
            :loading="directMessageStore.loadingNavigation"
            :selected-direct-message-id="directMessageStore.directMessageId ?? undefined"
            @open="selectOpenedDirectMessage"
            @select="selectDirectMessage"
          />
          </div>
        </div>
        <VoiceDock class="mobile-voice-dock" :activation-mode="voiceActivation.mode" :channel="activeVoiceChannel" :active-session="voiceConnection.active !== null" :error="voiceConnection.error" :deafen-changing="voiceConnection.deafenChanging" :deafened="voiceConnection.deafened"
          :microphone-muted="voiceConnection.microphoneMuted" :microphone-permission-denied="voiceConnection.microphonePermissionDenied" :screen-share-state="voiceConnection.screenState" :connection-quality="voiceConnection.connectionQuality" :ping-ms="voiceConnection.pingMs" :state="voiceConnection.state" @leave="leaveVoice" @start-screen="openScreenShareSetup" @stop-screen="voiceConnection.stopScreen"
          @toggle-deafen="voiceConnection.toggleDeafen" @toggle-microphone="voiceConnection.toggleMicrophone" />
        <WorkspaceUserFooter :role="props.role" :display-name="profile?.display_name" :avatar-u-r-l="profile?.avatar_url" @open-profile="togglePanel('profile')" @open-settings="togglePanel('audio')" />
      </aside>
      <main id="main-region" class="main" data-testid="main-region">
        <WorkspaceMain :account-id="props.accountId" :active-voice-channel="activeVoiceChannel" :panel="activePanel === 'search' ? 'none' : activePanel" :channel="selectedChannel" :direct-message="selectedDirectMessage" :join-voice="joinVoice" :leave-voice="leaveVoice" :activation-mode="voiceActivation.mode" :start-screen="openScreenShareSetup" :selected-screen-profile="selectedScreenProfile"
          :self-display-name="profile?.display_name ?? null" :nav-open="navOpen" :members-open="memberHeaderExpandedState" :show-members="!selectedDirectMessage && activePanel === 'none'" :voice-connection="voiceConnection" :voice-roster="voiceRoster.channels.value?.find((room) => room.channelId === selectedChannel?.id) ?? null" :voice-roster-error="voiceRoster.error.value"
          @return-voice="returnToVoice" @toggle-nav="toggleNavigation" @toggle-members="toggleMembers">
          <template #admin>
            <AdminPanel v-if="props.role === 'ADMINISTRATOR'" :categories="topologyStore.topology?.categories ?? []" :revision="topologyStore.topology?.revision ?? 0" @topology-changed="refreshTopology" />
          </template>
          <template #profile><ProfileSettings :profile="profile" :loading="profileLoading" :load-error="profileError" :logout-busy="logoutBusy" :logout-error="logoutError" @saved="setProfile" @logout="signOut" /></template>
          <template #audio>
            <AudioSettings :activation-error="voiceActivation.error" :activation-mode="voiceActivation.mode" :connected="Boolean(voiceConnection.active)" :devices="audioSettings.devices" :error="audioSettings.error" :processing="audioSettings.processing"
              :processing-diagnostics="voiceConnection.audioProcessingDiagnostics" :ptt-key="voiceActivation.pttKey" :state="audioSettings.state" @load="audioSettings.load" @select="selectAudioDevice" @set-activation="voiceActivation.setMode"
              @set-processing="audioSettings.setProcessing($event, voiceConnection.setAudioProcessing)" @set-ptt-key="voiceActivation.setPttKey" />
          </template>
        </WorkspaceMain>
      </main>
      <WorkspaceMembersPanel v-if="!selectedDirectMessage && activePanel === 'none'" :open="membersOpen" :active-voice-channel="activeVoiceChannel" :selected-voice-channel="selectedChannel?.kind === 'VOICE' ? selectedChannel : null" :participants="voiceConnection.voiceVolumeParticipants" :presence-resolver="guildPresence.resolve" :role="props.role" :account-i-d="profile?.account_id" :self-name="profile?.display_name ?? null" :self-microphone-muted="voiceConnection.microphoneMuted" :self-microphone-unavailable="voiceConnection.microphonePermissionDenied" :modal="modalDrawer === 'members'" @open-d-m="openDirectMessageFromMember" @set-volume="setParticipantVolume" />
      <aside v-else-if="activePanel === 'search'" id="search-aside-panel" class="members search-aside" :class="{ 'is-open': activePanel === 'search' }" :role="modalDrawer === 'search' ? 'dialog' : undefined" :aria-modal="modalDrawer === 'search' ? 'true' : undefined" aria-label="Поиск сообщений" tabindex="-1" data-testid="search-aside-panel"><WorkspaceSearchPanel @open-channel="selectChannel" @open-direct-message="selectDirectMessage" @close="activePanel = 'none'" /></aside>
      <button v-if="navOpen || membersOpen || activePanel === 'search'" class="drawer-scrim" type="button" aria-label="Закрыть навигацию и участников" @click="closeDrawers(); activePanel = 'none'" />
    </div>
    <ScreenShareSetupDialog v-if="screenShareSetupOpen" :initial-profile="voiceConnection.screenProfile ?? selectedScreenProfile" :updating="voiceConnection.screenState === 'SHARING'" @cancel="screenShareSetupOpen = false" @start="confirmScreenShare" />
  </div>
</template>
