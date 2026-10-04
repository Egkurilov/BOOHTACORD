<script setup lang="ts">
import { streamStartChime } from './stream_start_runtime'

const enabled = streamStartChime.enabled
function toggle(): void {
  streamStartChime.setEnabled(!enabled.value)
  if (enabled.value) streamStartChime.activate()
}
</script>

<template>
  <div class="audio-processing-row">
    <div>Звук начала трансляций<small>Сигнал, когда участник начинает показ экрана</small></div>
    <button type="button" role="switch" :aria-label="enabled ? 'Звук начала трансляций включён' : 'Звук начала трансляций выключен'" :aria-checked="enabled" @click="toggle" />
  </div>
</template>
