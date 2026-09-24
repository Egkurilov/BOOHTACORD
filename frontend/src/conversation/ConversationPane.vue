<script setup lang="ts">
import { computed, ref } from 'vue'

import type { TopologyChannel } from '../channel/topology_client'
import DirectMessageConversation from '../direct_message/DirectMessageConversation.vue'
import type { DirectMessageListItem } from '../direct_message/direct_message_client'
import type { ScreenShareState, VoiceConnectionState } from '../voice/connection_store'
import type { VoiceActivationMode } from '../voice/activation_store'
import type { ScreenProfile, VoiceJoinMode } from '../voice/livekit_gateway'
import type { ScreenDiagnostics } from '../voice/screen_diagnostics'
import ScreenDiagnosticsPanel from '../voice/ScreenDiagnosticsPanel.vue'
import ScreenViewer from '../voice/ScreenViewer.vue'
import VoicePrejoin from '../voice/VoicePrejoin.vue'
import VoiceRoomFooter from '../voice/VoiceRoomFooter.vue'
import VoiceParticipantVolumes from '../voice/VoiceParticipantVolumes.vue'
import type { ScreenViewerCard } from '../voice/screen_viewer_controller'
import type { VoiceVolumeParticipant } from '../voice/voice_volume_controls'
import { voiceRoomSummary } from '../voice/voice_room_copy'
import TextConversation from './TextConversation.vue'
import WorkspaceHeaderActions from '../workspace/WorkspaceHeaderActions.vue'

const props = defineProps<{
  channel: TopologyChannel | null
  directMessage: DirectMessageListItem | null
  navOpen: boolean
  membersOpen: boolean
  showMembers: boolean
  selfDisplayName: string | null; selfDeafened: boolean
  voiceError: string | null
  voiceIsActive: boolean
  voiceState: VoiceConnectionState
  activationMode: VoiceActivationMode
  voiceTransferRequired: boolean
  screenError: string | null
  screenViewerCards: ScreenViewerCard[]
  screenViewerEnded: boolean
  screenViewerError: string | null
  screenDiagnostics: ScreenDiagnostics
  screenProfile: ScreenProfile | null
  screenState: ScreenShareState
  selectedScreenStreamId: string | null
  selectedScreenAudioVolume: number
  selfMicrophoneMuted: boolean
  selfMicrophoneUnavailable: boolean
  selfSpeaking: boolean
  voiceVolumeError: string | null
  voiceVolumeParticipants: VoiceVolumeParticipant[]
}>()

const emit = defineEmits<{ clearScreenStream: []; join: [channelId: string, transfer?: boolean, joinMode?: VoiceJoinMode]; leave: []; refreshScreen: []; selectScreenStream: [id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null]; setParticipantVolume: [id: string, percent: number]; setScreenVolume: [percent: number]; startScreen: [profile: ScreenProfile]; stopScreen: []; transfer: [channelId: string]; toggleNav: []; toggleMembers: [] }>()
const selectedScreenProfile = ref<ScreenProfile>('P1080_60')
const screenExpanded = ref(false)
const selectedScreenName = computed(() => props.screenViewerCards.find((screen) => screen.id === props.selectedScreenStreamId)?.participantName ?? null)
const screenViewerRef = ref<{ selectStream: (id: string) => void } | null>(null)
function watchScreen(id: string): void { screenViewerRef.value?.selectStream(id) }
</script>

<template>
  <section class="conversation-pane" aria-live="polite">
    <template v-if="directMessage">
      <DirectMessageConversation :direct-message-id="directMessage.id" :other-participant-display-name="directMessage.otherParticipantDisplayName" :nav-open="navOpen" @toggle-nav="emit('toggleNav')" />
    </template>
    <template v-else-if="!channel">
      <p class="eyebrow">Рабочая область</p>
      <h2>Выберите канал</h2>
      <p>Навигация показывает только данные, полученные от текущей серверной сессии.</p>
    </template>
    <template v-else-if="channel.kind === 'TEXT'">
      <TextConversation :channel-id="channel.id" :channel-name="channel.name" :nav-open="navOpen" :members-open="membersOpen" :show-members="showMembers" @toggle-nav="emit('toggleNav')" @toggle-members="emit('toggleMembers')" />
    </template>
    <template v-else>
      <Teleport to="body" :disabled="!screenExpanded">
        <section class="voice-room" :class="{ 'voice-room--screen-expanded': screenExpanded }">
          <header class="main-header conversation-header">
            <span class="conversation-symbol" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M3 9v6h4l5 4V5L7 9H3ZM16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11" /></svg></span>
            <div class="main-title"><h2>{{ channel.name }}</h2><small>{{ selectedScreenName ? `Демонстрация ${selectedScreenName}` : voiceIsActive ? `Голосовой канал · участников: ${voiceVolumeParticipants.length + 1}` : 'Голосовой канал · подключитесь, чтобы увидеть участников' }}</small></div>
            <WorkspaceHeaderActions :members-expanded="membersOpen" :nav-expanded="navOpen" :show-members="showMembers" @toggle-members="emit('toggleMembers')" @toggle-navigation="emit('toggleNav')" />
          </header>
          <template v-if="screenViewerCards.length || selectedScreenStreamId || screenViewerEnded">
            <ScreenViewer
              ref="screenViewerRef" v-show="selectedScreenStreamId !== null || screenViewerEnded" :cards="screenViewerCards" :ended="screenViewerEnded" :error="screenViewerError" :expanded="screenExpanded" :selected-audio-volume="selectedScreenAudioVolume" :selected-id="selectedScreenStreamId"
              @clear="emit('clearScreenStream')" @select="(id, video, audio) => emit('selectScreenStream', id, video, audio)" @set-audio-volume="emit('setScreenVolume', $event)"
              @update:expanded="screenExpanded = $event"
            />
          </template>
          <div v-if="!selectedScreenStreamId && !screenViewerEnded" class="room-wrap">
            <p v-if="channel.admissionClosed" class="state state-error">Вход в этот канал закрыт администратором.</p>
            <template v-else-if="voiceIsActive">
              <div class="room-intro">
                <div class="room-intro-copy">
                  <h3>{{ voiceState === 'RECONNECTING' ? 'Восстанавливаем связь' : 'Все в сборе' }}</h3>
                  <p>{{ voiceState === 'RECONNECTING' ? 'Состояние микрофона сохранено.' : voiceRoomSummary(voiceVolumeParticipants.length + 1, screenViewerCards.length) }}</p>
                </div>
                <button v-if="screenState !== 'SHARING'" class="gc-button gc-button--primary" type="button" :disabled="screenState === 'STARTING'" @click="emit('startScreen', selectedScreenProfile)">{{ screenState === 'STARTING' ? 'Открываем выбор экрана…' : 'Показать экран' }}</button>
                <button v-else class="gc-button gc-button--secondary" type="button" @click="emit('stopScreen')">Остановить показ</button>
              </div>
              <p v-if="screenError" class="state state-error" role="alert">{{ screenError }}</p>
              <VoiceParticipantVolumes :error="voiceVolumeError" :participants="voiceVolumeParticipants" :screen-streams="screenViewerCards" :selected-screen-stream-id="selectedScreenStreamId" :self-name="selfDisplayName" :self-deafened="selfDeafened" :self-microphone-muted="selfMicrophoneMuted" :self-microphone-unavailable="selfMicrophoneUnavailable" :self-speaking="selfSpeaking" @set-volume="(id, percent) => emit('setParticipantVolume', id, percent)" @watch-screen="watchScreen" />
              <details class="voice-advanced"><summary>Параметры демонстрации</summary><ScreenDiagnosticsPanel v-if="screenState === 'SHARING'" :diagnostics="screenDiagnostics" :profile="screenProfile" @refresh="emit('refreshScreen')" /><label class="screen-settings">Целевой профиль<select v-model="selectedScreenProfile" :disabled="screenState === 'STARTING' || screenState === 'SHARING'"><option value="P720_30">720p · 30 FPS</option><option value="P720_60">720p · 60 FPS</option><option value="P1080_30">1080p · 30 FPS</option><option value="P1080_60">1080p · 60 FPS</option></select></label></details>
            </template>
            <VoicePrejoin v-else :channel-id="channel.id" :voice-error="voiceError" :voice-state="voiceState" :voice-transfer-required="voiceTransferRequired" @join="(id, transfer, mode) => emit('join', id, transfer, mode)" @transfer="emit('transfer', $event)" />
          </div>
          <VoiceRoomFooter v-if="voiceIsActive && !selectedScreenStreamId && !screenViewerEnded" :activation-mode="activationMode" :channel-name="channel.name" :state="voiceState" @leave="emit('leave')" />
        </section>
      </Teleport>
    </template>
  </section>
</template>
