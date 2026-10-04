<script setup lang="ts">
import type { VoiceDisconnectNotice } from './model'
defineProps<{ notice: VoiceDisconnectNotice; announce?: boolean }>()
</script>
<template>
  <div class="state state-error" :role="announce === false ? undefined : 'status'" :aria-live="announce === false ? undefined : 'polite'" aria-atomic="true" data-testid="voice-disconnect-notice">
    <p>{{ notice.message }}</p><p v-if="notice.explanation">{{ notice.explanation }}</p>
  </div>
</template>
