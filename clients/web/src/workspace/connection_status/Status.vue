<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount, ref } from 'vue'
import type { RealtimeState } from '../../realtime/realtime_store'
import type { VoiceConnectionState } from '../../voice/connection_store'
import { connectionStatus } from './model'
const props = defineProps<{ chat: RealtimeState; voice: VoiceConnectionState;
  rosterAvailable: boolean; lastUpdatedAt: number | null; rosterRetained?: boolean }>()
const emit = defineEmits<{ retryChat: []; retryRoster: [] }>()
const now = ref(Date.now())
let timer: ReturnType<typeof setInterval> | undefined
onMounted(() => { timer = setInterval(() => { now.value = Date.now() }, 1000) })
onBeforeUnmount(() => clearInterval(timer))
const status = computed(() => connectionStatus(props.chat, props.voice, props.rosterAvailable, props.lastUpdatedAt, now.value, props.rosterRetained))
const visible = computed(() => props.chat !== 'CONNECTED' || !props.rosterAvailable || ['RECONNECTING', 'ERROR'].includes(props.voice))
</script>
<template>
  <section v-if="visible" class="connection-status" aria-label="Состояние подключений" data-testid="connection-status">
    <p role="status">{{ status.chat }}</p>
    <button v-if="chat !== 'CONNECTED'" type="button" @click="emit('retryChat')">Повторить связь чата</button>
    <p role="status">{{ status.voice }}</p>
    <p>{{ status.roster }}</p>
    <button v-if="!rosterAvailable" type="button" @click="emit('retryRoster')">Обновить состав</button>
  </section>
</template>
<style scoped>
.connection-status { padding: 8px 12px; font-size: 0.6875rem; border-top: 1px solid color-mix(in srgb, currentColor 20%, transparent); }
.connection-status p { margin: 3px 0; }
.connection-status button { font: inherit; padding: 3px 0; text-decoration: underline; }
</style>
