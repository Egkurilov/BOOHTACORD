<script setup lang="ts">
import type { VoiceConnectionState } from './connection_store'
import type { VoiceJoinMode } from './livekit_gateway'
import VoiceRoomRoster from './VoiceRoomRoster.vue'
import type { VoiceRoomRoster as RoomRoster } from './voice_roster_client'

defineProps<{ channelId: string; voiceError: string | null; voiceState: VoiceConnectionState; voiceTransferRequired: boolean; roster?: RoomRoster | null; rosterError?: string | null }>()
const emit = defineEmits<{ join: [channelId: string, transfer?: boolean, joinMode?: VoiceJoinMode]; transfer: [channelId: string] }>()
</script>

<template>
  <div class="voice-prejoin">
    <article class="voice-prejoin-card" aria-labelledby="voice-prejoin-title">
      <span class="voice-prejoin-icon" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 3a3 3 0 0 0-3 3v5a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3Zm-7 8a7 7 0 0 0 14 0M12 18v3m-4 0h8" /></svg></span>
      <p class="eyebrow">ГОЛОСОВАЯ КОМНАТА</p>
      <h3 id="voice-prejoin-title" aria-live="polite" aria-atomic="true">{{ voiceState === 'JOINING' ? 'Подключаемся к голосовой комнате' : 'Вы не подключены' }}</h3>
      <p class="voice-prejoin-copy">{{ voiceState === 'JOINING' ? 'Соединение устанавливается.' : 'Посмотрите, кто сейчас в комнате, и выберите удобный способ подключения.' }}</p>
      <VoiceRoomRoster v-if="roster" :roster="roster" />
      <p v-else-if="rosterError" class="state state-error" role="status">Не удалось обновить состав комнаты. Повторяем попытку.</p>
      <p v-else class="state" role="status">Проверяем, кто сейчас в комнате…</p>
      <p v-if="voiceError" class="state state-error" role="alert">{{ voiceError }}</p>
      <div class="voice-prejoin-actions">
        <button class="gc-button gc-button--primary" type="button" :disabled="voiceState === 'JOINING'" @click="emit('join', channelId)">{{ voiceState === 'JOINING' ? 'Подключаемся…' : 'Подключиться к голосу' }}</button>
        <button class="gc-button gc-button--secondary" type="button" :disabled="voiceState === 'JOINING'" @click="emit('join', channelId, true, 'listener')">Подключиться без микрофона</button>
      </div>
    </article>
  </div>
</template>
