<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import AdminTopologyControls from '../channel/AdminTopologyControls.vue'
import ChannelNavigation from '../channel/ChannelNavigation.vue'
import type { TopologyChannel } from '../channel/topology_client'
import DirectMessageNavigation from '../direct_message/DirectMessageNavigation.vue'
import { useDirectMessageStore } from '../direct_message/direct_message_store'
import VoiceDock from '../voice/VoiceDock.vue'
import AudioSettings from '../voice/AudioSettings.vue'
import { useMessageStore } from '../conversation/message_store'
import { useRealtimeStore } from '../realtime/realtime_store'
import { useWorkspaceVoiceControls } from './voice_controls'
import WorkspaceMain from './WorkspaceMain.vue'
import WorkspaceMembersPanel from './WorkspaceMembersPanel.vue'
import WorkspaceSidebarTabs from './WorkspaceSidebarTabs.vue'
import WorkspaceUserFooter from './WorkspaceUserFooter.vue'
const props = defineProps<{ role: 'MEMBER' | 'ADMINISTRATOR' }>()
const { activeVoiceChannel, audioSettings, joinVoice, leaveVoice, selectAudioDevice, selectedChannel, selectedChannelId, selectChannel: selectWorkspaceChannel, selectDirectMessage: selectWorkspaceDirectMessage, startScreen, topologyStore, voiceActivation, voiceConnection } = useWorkspaceVoiceControls()
const directMessageStore = useDirectMessageStore()
const messageStore = useMessageStore()
const realtimeStore = useRealtimeStore()
const sidebarSection = ref<'channels' | 'messages'>('channels')
const activePanel = ref<'none' | 'admin' | 'audio'>('none')
const selectedDirectMessage = computed(() => directMessageStore.directMessages.find((item) => item.id === directMessageStore.directMessageId) ?? null)
function selectChannel(channel: TopologyChannel): void { sidebarSection.value = 'channels'; directMessageStore.close(); selectWorkspaceChannel(channel) }
function selectDirectMessage(directMessageId: string): void { sidebarSection.value = 'messages'; selectWorkspaceDirectMessage(directMessageId); void directMessageStore.open(directMessageId) }
async function selectOpenedDirectMessage(directMessageId: string): Promise<void> { await directMessageStore.refreshNavigation(); selectDirectMessage(directMessageId) }
function resync(): void { void topologyStore.refresh(); void messageStore.refresh(); void directMessageStore.refreshNavigation(); void directMessageStore.refreshHistory() }
function refreshTopology(): void { void topologyStore.refresh() }
function togglePanel(panel: 'admin' | 'audio'): void { activePanel.value = activePanel.value === panel ? 'none' : panel }
function openGuildPanel(): void { if (props.role === 'ADMINISTRATOR') togglePanel('admin') }

onMounted(() => { void topologyStore.refresh(); void directMessageStore.refreshNavigation(); realtimeStore.connect(resync) })
onBeforeUnmount(() => realtimeStore.disconnect())
</script>

<template>
  <div class="app-frame">
    <a class="gc-sr-only" href="#main-region">Перейти к содержимому</a>
    <div class="gc-shell" :class="{ 'no-aside': selectedDirectMessage }" data-testid="app-shell">
      <aside class="sidebar" aria-label="Навигация гильдии" data-testid="nav-sidebar">
        <button class="guild-header" type="button" :aria-expanded="activePanel === 'admin'" @click="openGuildPanel"><span class="guild-mark" aria-hidden="true">V</span><span id="app-title">Voice Platform</span></button>
        <WorkspaceSidebarTabs class="sidebar-tabs" :active="sidebarSection" @select="sidebarSection = $event" />

        <div class="nav-content">
          <AdminTopologyControls v-if="activePanel === 'admin' && props.role === 'ADMINISTRATOR' && topologyStore.topology" :categories="topologyStore.topology.categories" :revision="topologyStore.topology.revision" @changed="refreshTopology" />
          <AudioSettings
            v-if="activePanel === 'audio'"
            :activation-error="voiceActivation.error" :activation-mode="voiceActivation.mode" :devices="audioSettings.devices" :error="audioSettings.error" :processing="audioSettings.processing" :processing-diagnostics="voiceConnection.audioProcessingDiagnostics" :ptt-key="voiceActivation.pttKey" :state="audioSettings.state"
            @load="audioSettings.load" @select="selectAudioDevice" @set-activation="voiceActivation.setMode" @set-processing="audioSettings.setProcessing($event, voiceConnection.setAudioProcessing)" @set-ptt-key="voiceActivation.setPttKey"
          />
          <template v-if="sidebarSection === 'channels'">
            <p v-if="topologyStore.loading" class="state" aria-live="polite">Загружаем каналы…</p>
            <p v-else-if="topologyStore.error" class="state state-error" role="alert">{{ topologyStore.error }} Войдите в аккаунт или повторите попытку.</p>
            <template v-else-if="topologyStore.topology">
              <ChannelNavigation :active-voice-channel-id="activeVoiceChannel?.id" :selected-channel-id="selectedChannelId ?? undefined" :topology="topologyStore.topology" @select="selectChannel" />
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

        <VoiceDock
          :activation-mode="voiceActivation.mode"
          :channel="activeVoiceChannel"
          :deafen-changing="voiceConnection.deafenChanging"
          :deafened="voiceConnection.deafened"
          :microphone-muted="voiceConnection.microphoneMuted"
          :microphone-permission-denied="voiceConnection.microphonePermissionDenied"
          :state="voiceConnection.state"
          @leave="leaveVoice"
          @start-screen="startScreen('P1080_60')"
          @toggle-deafen="voiceConnection.toggleDeafen"
          @toggle-microphone="voiceConnection.toggleMicrophone"
        />
        <WorkspaceUserFooter :role="props.role" @open-settings="togglePanel('audio')" />
      </aside>

      <main id="main-region" class="main" data-testid="main-region">
        <WorkspaceMain
          :channel="selectedChannel"
          :direct-message="selectedDirectMessage"
          :join-voice="joinVoice"
          :start-screen="startScreen"
          :voice-connection="voiceConnection"
        />
      </main>

      <WorkspaceMembersPanel v-if="!selectedDirectMessage" :active-voice-channel="activeVoiceChannel" :participants="voiceConnection.voiceVolumeParticipants" />
    </div>
  </div>
</template>
