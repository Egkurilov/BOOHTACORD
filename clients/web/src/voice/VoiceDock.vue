<script setup lang="ts">
import { computed } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import type { ScreenShareState, VoiceConnectionState } from './connection_store'
import type { VoiceActivationMode } from './activation_store'
import { streamStartChime, streamStartNotice } from './stream_start_runtime'
import { screenCaptureSupported, screenCaptureUnavailableMessage } from './screen_capture_support'
import { voiceConnectionQualityLabel, type VoiceConnectionQuality } from './voice_connection_quality'

const props = withDefaults(defineProps<{
  channel: TopologyChannel | null
  activeSession: boolean
  error: string | null
  activationMode: VoiceActivationMode
  deafened: boolean
  deafenChanging: boolean
  microphoneMuted: boolean
  microphonePermissionDenied: boolean
  screenShareState?: ScreenShareState
  connectionQuality?: VoiceConnectionQuality
  pingMs?: number | null
  state: VoiceConnectionState
}>(), { screenShareState: 'IDLE', connectionQuality: 'UNKNOWN', pingMs: null })
const emit = defineEmits<{ leave: []; startScreen: []; stopScreen: []; toggleDeafen: []; toggleMicrophone: [] }>()
const streamSoundEnabled = streamStartChime.enabled
const screenCaptureAvailable = screenCaptureSupported()
const captureUnavailableMessage = screenCaptureUnavailableMessage()
function toggleStreamSound(): void {
  streamStartChime.setEnabled(!streamSoundEnabled.value)
  if (streamSoundEnabled.value) streamStartChime.activate()
}
const connected = computed(() => (props.channel !== null || props.activeSession) && (props.state === 'CONNECTED' || props.state === 'LISTENER'))
const screenShareBusy = computed(() => props.screenShareState === 'STARTING' || props.screenShareState === 'STOPPING')
const connectionQualityLabel = computed(() => voiceConnectionQualityLabel(props.connectionQuality))
const connectionPingLabel = computed(() => props.pingMs === null ? '—' : `${props.pingMs} мс`)
const connectionQualityDescription = computed(() => `Качество соединения: ${connectionQualityLabel.value} · ping ${connectionPingLabel.value}`)
const status = computed(() => {
  if (props.state === 'JOINING') return 'Подключаемся к голосовому каналу'
  if (props.state === 'RECONNECTING') return 'Восстанавливаем голосовое соединение'
  if (props.state === 'LEAVING') return 'Завершаем голосовое подключение'
  if (props.channel) return 'В голосовом канале'
  return props.activeSession ? 'Голос подключён · канал не отображается' : 'Голос не подключён'
})
</script>

<template>
  <section class="voice-dock" :class="{ connected }" aria-label="Состояние голосового подключения" data-testid="voice-dock">
    <div class="voice-dock-header">
      <span class="status-dot" :class="{ connected }" aria-hidden="true"></span>
      <p class="voice-status" role="status" aria-atomic="true">{{ status }}<span v-if="channel" class="voice-status-channel"> · {{ channel.name }}</span></p>
      <span v-if="connected" class="voice-quality" :class="`voice-quality--${connectionQuality.toLowerCase()}`" role="img" :aria-label="connectionQualityDescription" :title="connectionQualityDescription">
        <svg class="voice-quality-icon" viewBox="0 0 20 20" aria-hidden="true"><path d="M2 13h3v5H2zM7 9h3v9H7zM12 5h3v13h-3zM17 1h2v17h-2z" /></svg>
        <span>{{ connectionPingLabel }}</span>
      </span>
    </div>
    <p v-if="streamStartNotice && activeSession" class="voice-stream-alert-notice" role="status">В канале началась демонстрация экрана</p>
    <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
    <div v-if="channel || activeSession" class="voice-actions">
      <button v-if="channel" class="voice-icon-button" type="button" :aria-label="microphoneMuted ? 'Включить микрофон' : 'Выключить микрофон'" :aria-pressed="!microphoneMuted" :disabled="activationMode === 'PTT' || deafened" :title="activationMode === 'PTT' ? 'Микрофон управляется PTT' : microphoneMuted ? 'Включить микрофон' : 'Выключить микрофон'" @click="emit('toggleMicrophone')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M8 10v4a4 4 0 0 0 8 0v-4M12 18v3M8 21h8M12 3a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z" /></svg></button>
      <button v-if="channel" class="voice-icon-button" type="button" :aria-label="deafened ? 'Включить удалённый звук' : 'Выключить удалённый звук'" :aria-pressed="deafened" :disabled="deafenChanging || state === 'LEAVING'" :title="deafened ? 'Включить удалённый звук' : 'Выключить удалённый звук'" @click="emit('toggleDeafen')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10v4h4l5 4V6L8 10H4ZM16 9.5a4 4 0 0 1 0 5M18.5 7a7 7 0 0 1 0 10" /></svg></button>
      <button v-if="channel" class="voice-icon-button" type="button" :aria-label="screenShareState === 'SHARING' ? 'Остановить демонстрацию экрана' : screenCaptureAvailable ? 'Начать демонстрацию экрана' : captureUnavailableMessage" :aria-pressed="screenShareState === 'SHARING'" :disabled="screenShareBusy || state === 'JOINING' || state === 'RECONNECTING' || state === 'LEAVING' || (screenShareState !== 'SHARING' && !screenCaptureAvailable)" :title="screenShareState === 'SHARING' ? 'Остановить демонстрацию экрана' : screenCaptureAvailable ? 'Начать демонстрацию экрана' : captureUnavailableMessage" @click="screenShareState === 'SHARING' ? emit('stopScreen') : emit('startScreen')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path v-if="screenShareState === 'SHARING'" d="M4 4h16v12H4zM8 20h8M12 16v4M9 9l6 6m0-6-6 6" /><path v-else d="M4 4h16v12H4zM8 20h8M12 16v4M12 7v6M9 10l3-3 3 3" /></svg></button>
      <button class="voice-icon-button voice-stream-alert-toggle" type="button" :aria-label="streamSoundEnabled ? 'Звук начала трансляций включён' : 'Звук начала трансляций выключен'" :aria-pressed="streamSoundEnabled" :title="streamSoundEnabled ? 'Выключить сигнал новых трансляций' : 'Включить сигнал новых трансляций'" @click="toggleStreamSound"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4M4 3l16 18" v-if="!streamSoundEnabled" /><path v-else d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4" /></svg></button>
      <button class="voice-icon-button voice-icon-button--danger" type="button" aria-label="Выйти из голосового канала" :disabled="state === 'LEAVING'" :title="state === 'LEAVING' ? 'Выходим…' : 'Выйти из голосового канала'" @click="emit('leave')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 17H5V7h4M15 7l4 5-4 5M19 12H9" /></svg></button>
    </div>
  </section>
</template>
