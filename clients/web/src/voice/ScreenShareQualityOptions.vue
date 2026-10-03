<script setup lang="ts">
import type { ScreenFrameRate, ScreenResolution } from './media_publishing'
defineProps<{ resolution: ScreenResolution; frameRate: ScreenFrameRate }>()
const emit = defineEmits<{ 'update:resolution': [value: ScreenResolution]; 'update:frameRate': [value: ScreenFrameRate] }>()
const resolutions: readonly ScreenResolution[] = [720, 1080, 1440]
const frameRates: readonly ScreenFrameRate[] = [15, 30, 60]
</script>
<template>
  <fieldset class="screen-share-quality__row"><legend>Разрешение</legend>
    <div class="screen-share-quality__segments" role="radiogroup" aria-label="Разрешение трансляции">
      <label v-for="value in resolutions" :key="value" class="screen-share-quality__option"><input :checked="resolution === value" type="radio" name="screen-share-resolution" :value="value" @change="emit('update:resolution', value)"><span>{{ value }}p</span></label>
    </div>
  </fieldset>
  <fieldset class="screen-share-quality__row"><legend>Частота кадров</legend>
    <div class="screen-share-quality__segments" role="radiogroup" aria-label="Частота кадров трансляции">
      <label v-for="value in frameRates" :key="value" class="screen-share-quality__option"><input :checked="frameRate === value" type="radio" name="screen-share-frame-rate" :value="value" @change="emit('update:frameRate', value)"><span>{{ value }} FPS</span></label>
    </div>
  </fieldset>
</template>
