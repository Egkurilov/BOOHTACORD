<script setup lang="ts">
import { computed } from 'vue'
import type { TopologyChannel } from '../channel/topology_client'
import type { VoiceConnectionState } from './connection_store'
import type { VoiceActivationMode } from './activation_store'

const props = defineProps<{
  channel: TopologyChannel | null
  activeSession: boolean
  error: string | null
  activationMode: VoiceActivationMode
  deafened: boolean
  deafenChanging: boolean
  microphoneMuted: boolean
  microphonePermissionDenied: boolean
  state: VoiceConnectionState
}>()
const emit = defineEmits<{ leave: []; startScreen: []; toggleDeafen: []; toggleMicrophone: [] }>()
const connected = computed(() => (props.channel !== null || props.activeSession) && (props.state === 'CONNECTED' || props.state === 'LISTENER'))
const status = computed(() => {
  if (props.state === 'JOINING') return 'Подключаемся к голосовому каналу'
  if (props.state === 'RECONNECTING') return 'Восстанавливаем голосовое соединение'
  if (props.state === 'LEAVING') return 'Завершаем голосовое подключение'
  if (props.channel) return 'В голосовом канале'
  return props.activeSession ? 'Голос подключён · канал не отображается' : 'Голос не подключён'
})
const hint = computed(() => {
  if (props.state === 'JOINING') return 'Соединяемся с голосовой комнатой.'
  if (props.state === 'RECONNECTING') return 'Ручной выход отменит ожидание.'
  if (props.state === 'LEAVING') return 'Ожидаем завершения голосовой сессии.'
  if (!props.channel && props.activeSession) return 'Канал сейчас не отображается. Вы можете безопасно выйти вручную.'
  if (props.deafened) return 'Удалённый звук и микрофон выключены. Показ экрана этой кнопкой не отключается.'
  if (props.microphonePermissionDenied) return 'Микрофон недоступен: вы остаётесь слушателем.'
  return props.channel ? 'Вы можете открыть другой канал: голос останется активным.' : 'Откройте голосовой канал, чтобы подготовить подключение.'
})
</script>

<template>
  <section class="voice-dock" :class="{ connected }" aria-label="Состояние голосового подключения" data-testid="voice-dock">
    <div class="voice-dock-header">
      <span class="status-dot" :class="{ connected }" aria-hidden="true"></span>
      <p class="voice-status" role="status" aria-atomic="true">{{ status }}<span v-if="channel" class="voice-status-channel"> · {{ channel.name }}</span></p>
    </div>
    <p class="voice-hint">{{ hint }}</p>
    <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
    <div v-if="channel || activeSession" class="voice-actions">
      <button v-if="channel" class="voice-icon-button" type="button" :aria-label="microphoneMuted ? 'Включить микрофон' : 'Выключить микрофон'" :aria-pressed="!microphoneMuted" :disabled="activationMode === 'PTT' || deafened" :title="activationMode === 'PTT' ? 'Микрофон управляется PTT' : microphoneMuted ? 'Включить микрофон' : 'Выключить микрофон'" @click="emit('toggleMicrophone')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M8 10v4a4 4 0 0 0 8 0v-4M12 18v3M8 21h8M12 3a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Z" /></svg></button>
      <button v-if="channel" class="voice-icon-button" type="button" :aria-label="deafened ? 'Включить удалённый звук' : 'Выключить удалённый звук'" :aria-pressed="deafened" :disabled="deafenChanging || state === 'LEAVING'" :title="deafened ? 'Включить удалённый звук' : 'Выключить удалённый звук'" @click="emit('toggleDeafen')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10v4h4l5 4V6L8 10H4ZM16 9.5a4 4 0 0 1 0 5M18.5 7a7 7 0 0 1 0 10" /></svg></button>
      <button v-if="channel" class="voice-icon-button" type="button" aria-label="Начать демонстрацию экрана" :disabled="state === 'RECONNECTING' || state === 'LEAVING'" title="Начать демонстрацию экрана" @click="emit('startScreen')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 4h16v12H4zM8 20h8M12 16v4M12 7v6M9 10l3-3 3 3" /></svg></button>
      <button class="voice-icon-button voice-icon-button--danger" type="button" aria-label="Выйти из голосового канала" :disabled="state === 'LEAVING'" :title="state === 'LEAVING' ? 'Выходим…' : 'Выйти из голосового канала'" @click="emit('leave')"><svg class="voice-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M9 17H5V7h4M15 7l4 5-4 5M19 12H9" /></svg></button>
    </div>
  </section>
</template>
