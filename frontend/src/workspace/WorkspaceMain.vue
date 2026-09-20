<script setup lang="ts">
import type { TopologyChannel } from '../channel/topology_client'
import ConversationPane from '../conversation/ConversationPane.vue'
import type { DirectMessageListItem } from '../direct_message/direct_message_client'
import { useVoiceConnectionStore } from '../voice/connection_store'
import type { useWorkspaceVoiceControls } from './voice_controls'

type VoiceConnection = ReturnType<typeof useVoiceConnectionStore>
type WorkspaceVoiceControls = ReturnType<typeof useWorkspaceVoiceControls>

defineProps<{
  channel: TopologyChannel | null
  directMessage: DirectMessageListItem | null
  joinVoice: WorkspaceVoiceControls['joinVoice']
  startScreen: WorkspaceVoiceControls['startScreen']
  voiceConnection: VoiceConnection
}>()
</script>

<template>
  <ConversationPane
    :channel="channel"
    :direct-message="directMessage"
    :screen-diagnostics="voiceConnection.screenDiagnostics"
    :screen-error="voiceConnection.screenError"
    :screen-profile="voiceConnection.screenProfile"
    :screen-state="voiceConnection.screenState"
    :screen-viewer-cards="voiceConnection.screenViewerCards"
    :screen-viewer-error="voiceConnection.screenViewerError"
    :selected-screen-audio-volume="voiceConnection.selectedScreenAudioVolume"
    :selected-screen-stream-id="voiceConnection.selectedScreenStreamId"
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
  />
</template>
