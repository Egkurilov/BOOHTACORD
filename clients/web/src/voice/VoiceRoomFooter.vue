<script setup lang="ts">
import { computed } from 'vue'
import type { VoiceActivationMode } from './activation_store'
import type { VoiceConnectionState } from './connection_store'

const props = defineProps<{ channelName: string; state: VoiceConnectionState; activationMode: VoiceActivationMode }>()
const emit = defineEmits<{ leave: [] }>()
const status = computed(() => props.state === 'RECONNECTING' ? `Восстанавливаем связь с «${props.channelName}»` : props.state === 'LEAVING' ? 'Завершаем голосовое подключение…' : props.state === 'ERROR' ? 'Ошибка голосового подключения' : `Вы подключены к «${props.channelName}»`)
const hint = computed(() => props.state === 'LISTENER' ? 'Режим слушателя · микрофон не передаётся' : props.state === 'RECONNECTING' ? 'Ожидаем восстановления соединения' : props.activationMode === 'PTT' ? 'Нажми и говори' : 'Автоактивация голосом')
</script>

<template>
  <footer class="voice-room-footer" aria-label="Голосовое подключение" data-testid="voice-room-footer">
    <div class="voice-room-footer-copy"><p>{{ status }}</p><small>{{ hint }}</small></div>
    <button class="gc-button gc-button--secondary" type="button" :disabled="state === 'LEAVING'" @click="emit('leave')"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 15c4.8-4.3 13.2-4.3 18 0l-2 3-3-1.5v-2.2a13 13 0 0 0-8 0v2.2L5 18z" /></svg><span>Выйти из канала</span></button>
  </footer>
</template>
