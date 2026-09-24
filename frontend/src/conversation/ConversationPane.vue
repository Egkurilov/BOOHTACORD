<script setup lang="ts">
import { ref } from 'vue'

import type { TopologyChannel } from '../channel/topology_client'
import DirectMessageConversation from '../direct_message/DirectMessageConversation.vue'
import type { DirectMessageListItem } from '../direct_message/direct_message_client'
import type { ScreenShareState, VoiceConnectionState } from '../voice/connection_store'
import type { ScreenProfile } from '../voice/livekit_gateway'
import type { ScreenDiagnostics } from '../voice/screen_diagnostics'
import ScreenDiagnosticsPanel from '../voice/ScreenDiagnosticsPanel.vue'
import ScreenViewer from '../voice/ScreenViewer.vue'
import VoiceParticipantVolumes from '../voice/VoiceParticipantVolumes.vue'
import VoiceParticipantStrip from '../voice/VoiceParticipantStrip.vue'
import type { ScreenViewerCard } from '../voice/screen_viewer_controller'
import type { VoiceVolumeParticipant } from '../voice/voice_volume_controls'
import TextConversation from './TextConversation.vue'

defineProps<{
  channel: TopologyChannel | null
  directMessage: DirectMessageListItem | null
  voiceError: string | null
  voiceIsActive: boolean
  voiceState: VoiceConnectionState
  voiceTransferRequired: boolean
  screenError: string | null
  screenViewerCards: ScreenViewerCard[]
  screenViewerError: string | null
  screenDiagnostics: ScreenDiagnostics
  screenProfile: ScreenProfile | null
  screenState: ScreenShareState
  selectedScreenStreamId: string | null
  selectedScreenAudioVolume: number
  voiceVolumeError: string | null
  voiceVolumeParticipants: VoiceVolumeParticipant[]
}>()

const emit = defineEmits<{ clearScreenStream: []; join: [channelId: string]; refreshScreen: []; selectScreenStream: [id: string, video: HTMLVideoElement | null, audio: HTMLAudioElement | null]; setParticipantVolume: [id: string, percent: number]; setScreenVolume: [percent: number]; startScreen: [profile: ScreenProfile]; stopScreen: []; transfer: [channelId: string] }>()
const selectedScreenProfile = ref<ScreenProfile>('P1080_60')
</script>

<template>
  <section class="conversation-pane" aria-live="polite">
    <template v-if="directMessage">
      <DirectMessageConversation :direct-message-id="directMessage.id" :other-participant-display-name="directMessage.otherParticipantDisplayName" />
    </template>
    <template v-else-if="!channel">
      <p class="eyebrow">Рабочая область</p>
      <h2>Выберите канал</h2>
      <p>Навигация показывает только данные, полученные от текущей серверной сессии.</p>
    </template>
    <template v-else-if="channel.kind === 'TEXT'">
      <TextConversation :channel-id="channel.id" :channel-name="channel.name" />
    </template>
    <template v-else>
      <section class="voice-room">
        <header class="main-header conversation-header">
          <span class="conversation-symbol" aria-hidden="true">♬</span>
          <div class="main-title"><h2>{{ channel.name }}</h2><small>Голосовой канал · участников: {{ voiceVolumeParticipants.length + (voiceIsActive ? 1 : 0) }}</small></div>
        </header>
        <template v-if="screenViewerCards.length || selectedScreenStreamId">
          <ScreenViewer
            :cards="screenViewerCards" :error="screenViewerError" :selected-audio-volume="selectedScreenAudioVolume" :selected-id="selectedScreenStreamId"
            @clear="emit('clearScreenStream')" @select="(id, video, audio) => emit('selectScreenStream', id, video, audio)" @set-audio-volume="emit('setScreenVolume', $event)"
          />
          <VoiceParticipantStrip v-if="voiceIsActive" :error="voiceVolumeError" :participants="voiceVolumeParticipants" />
        </template>
        <div v-else class="room-wrap">
          <p v-if="channel.admissionClosed" class="state state-error">Вход в этот канал закрыт администратором.</p>
          <template v-else-if="voiceIsActive">
            <div class="room-intro">
              <p>{{ voiceState === 'RECONNECTING' ? 'Восстанавливаем связь. Состояние микрофона сохранено.' : 'Общайтесь и делитесь экраном.' }}</p>
              <button v-if="screenState !== 'SHARING'" class="gc-button gc-button--primary" type="button" :disabled="screenState === 'STARTING'" @click="emit('startScreen', selectedScreenProfile)">{{ screenState === 'STARTING' ? 'Открываем выбор экрана…' : 'Показать экран' }}</button>
              <button v-else class="gc-button gc-button--secondary" type="button" @click="emit('stopScreen')">Остановить показ</button>
            </div>
            <p v-if="screenError" class="state state-error" role="alert">{{ screenError }}</p>
            <VoiceParticipantVolumes :error="voiceVolumeError" :participants="voiceVolumeParticipants" @set-volume="(id, percent) => emit('setParticipantVolume', id, percent)" />
            <details class="voice-advanced"><summary>Параметры демонстрации</summary><ScreenDiagnosticsPanel v-if="screenState === 'SHARING'" :diagnostics="screenDiagnostics" :profile="screenProfile" @refresh="emit('refreshScreen')" /><label class="screen-settings">Целевой профиль<select v-model="selectedScreenProfile" :disabled="screenState === 'STARTING' || screenState === 'SHARING'"><option value="P720_30">720p · 30 FPS</option><option value="P720_60">720p · 60 FPS</option><option value="P1080_30">1080p · 30 FPS</option><option value="P1080_60">1080p · 60 FPS</option></select></label></details>
          </template>
          <template v-else>
            <p v-if="voiceError" class="state state-error" role="alert">{{ voiceError }}</p>
            <div class="room-intro"><p v-if="!voiceError">Вы ещё не подключены к этой комнате.</p><button v-if="voiceTransferRequired" class="gc-button gc-button--secondary" type="button" @click="emit('transfer', channel.id)">Перенести подключение</button><button class="gc-button gc-button--primary" type="button" :disabled="voiceState === 'JOINING'" @click="emit('join', channel.id)">{{ voiceState === 'JOINING' ? 'Подключаемся…' : 'Подключиться' }}</button></div>
          </template>
        </div>
      </section>
    </template>
  </section>
</template>
