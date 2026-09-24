<script setup lang="ts">
import type { TopologyChannel } from '../channel/topology_client'
import ConversationPane from '../conversation/ConversationPane.vue'
import type { DirectMessageListItem } from '../direct_message/direct_message_client'
import { useVoiceConnectionStore } from '../voice/connection_store'
import type { useWorkspaceVoiceControls } from './voice_controls'

type VoiceConnection = ReturnType<typeof useVoiceConnectionStore>
type WorkspaceVoiceControls = ReturnType<typeof useWorkspaceVoiceControls>

defineProps<{
  panel: 'none' | 'admin' | 'audio' | 'profile'
  channel: TopologyChannel | null
  directMessage: DirectMessageListItem | null
  joinVoice: WorkspaceVoiceControls['joinVoice']
  startScreen: WorkspaceVoiceControls['startScreen']
  navOpen: boolean
  membersOpen: boolean
  showMembers: boolean
  selfDisplayName: string | null
  voiceConnection: VoiceConnection
}>()
const emit = defineEmits<{ toggleNav: []; toggleMembers: [] }>()
</script>

<template>
  <div v-if="panel === 'admin'" class="workspace-main-panel workspace-main-panel--admin" data-testid="admin-workspace-panel">
    <slot name="admin" />
  </div>
  <div v-else-if="panel === 'audio'" class="workspace-main-panel workspace-main-panel--audio" data-testid="audio-workspace-panel">
    <slot name="audio" />
  </div>
  <div v-else-if="panel === 'profile'" class="workspace-main-panel workspace-main-panel--profile" data-testid="profile-workspace-panel">
    <slot name="profile" />
  </div>
  <ConversationPane
    v-else
    :channel="channel"
    :direct-message="directMessage"
    :nav-open="navOpen"
    :members-open="membersOpen"
    :show-members="showMembers"
    :self-display-name="selfDisplayName"
    :screen-diagnostics="voiceConnection.screenDiagnostics"
    :screen-error="voiceConnection.screenError"
    :screen-profile="voiceConnection.screenProfile"
    :screen-state="voiceConnection.screenState"
    :screen-viewer-cards="voiceConnection.screenViewerCards"
    :screen-viewer-ended="voiceConnection.screenViewerEnded"
    :screen-viewer-error="voiceConnection.screenViewerError"
    :selected-screen-audio-volume="voiceConnection.selectedScreenAudioVolume"
    :selected-screen-stream-id="voiceConnection.selectedScreenStreamId"
    :self-microphone-muted="voiceConnection.microphoneMuted"
    :self-microphone-unavailable="voiceConnection.microphonePermissionDenied"
    :self-speaking="voiceConnection.selfSpeaking"
    :voice-error="voiceConnection.error"
    :voice-is-active="channel?.id === voiceConnection.active?.channelId"
    :voice-state="voiceConnection.state"
    :voice-transfer-required="voiceConnection.transferRequired"
    :voice-volume-error="voiceConnection.voiceVolumeError"
    :voice-volume-participants="voiceConnection.voiceVolumeParticipants"
    @clear-screen-stream="voiceConnection.clearScreenStream"
    @join="joinVoice"
    @refresh-screen="voiceConnection.refreshScreenDiagnostics"
    @select-screen-stream="voiceConnection.selectScreenStream"
    @set-participant-volume="voiceConnection.setParticipantVolume"
    @set-screen-volume="voiceConnection.setScreenVolume"
    @start-screen="startScreen"
    @stop-screen="voiceConnection.stopScreen"
    @transfer="joinVoice($event, true)"
    @toggle-nav="emit('toggleNav')"
    @toggle-members="emit('toggleMembers')"
  />
</template>
