<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(defineProps<{ compact?: boolean; microphoneMuted: boolean; microphoneUnavailable?: boolean; speaking?: boolean }>(), { compact: false, microphoneUnavailable: false, speaking: false })
const isSpeaking = computed(() => props.speaking && !props.microphoneMuted && !props.microphoneUnavailable)
const state = computed(() => props.microphoneUnavailable ? 'Микрофон недоступен' : props.microphoneMuted ? 'Микрофон выключен' : isSpeaking.value ? 'Говорит' : 'В канале')
</script>

<template>
  <span class="voice-person-state" :class="{ 'is-muted': microphoneMuted || microphoneUnavailable, 'is-speaking': isSpeaking }" :aria-label="state" :title="state">
    <svg v-if="isSpeaking" class="voice-person-state-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10v4M8 7v10M12 4v16M16 7v10M20 10v4" /></svg>
    <svg v-else class="voice-person-state-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3ZM5 11v2a7 7 0 0 0 14 0v-2M12 20v2M9 22h6" /><path v-if="microphoneMuted || microphoneUnavailable" d="m4 4 16 16" /></svg>
    <span v-if="!compact">{{ state }}</span>
  </span>
</template>
