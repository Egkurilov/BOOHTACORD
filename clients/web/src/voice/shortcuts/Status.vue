<script setup lang="ts">
defineProps<{ message: string }>()
</script>
<template><p v-if="message" class="voice-shortcut-status" role="status" aria-live="polite" aria-atomic="true">{{ message }}</p></template>
<style scoped>.voice-shortcut-status { position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%); z-index: 120; padding: 12px 18px; max-width: min(90vw, 520px); border-radius: 12px; background: var(--gc-panel, #252836); color: var(--gc-text, #fff); box-shadow: 0 8px 32px #0006; pointer-events: none; }</style>
