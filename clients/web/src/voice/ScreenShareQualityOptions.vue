<script setup lang="ts">
import { computed } from 'vue'
import type { ScreenFrameRate, ScreenResolution } from './media_publishing'
const props = defineProps<{ resolution: ScreenResolution; frameRate: ScreenFrameRate; mode: 'motion' | 'text'; allow1440p60?: boolean; advancedOpen?: boolean }>()
const emit = defineEmits<{ 'update:resolution': [value: ScreenResolution]; 'update:frameRate': [value: ScreenFrameRate]; 'update:mode': [value: 'motion' | 'text'] }>()
const resolutions: readonly ScreenResolution[] = [720, 1080, 1440]
const frameRates = computed<readonly ScreenFrameRate[]>(() => props.mode === 'motion' ? [60] : [15, 30])
</script>
<template>
  <fieldset class="screen-share-quality__row screen-share-quality__mode"><legend>Сценарий</legend>
    <div class="screen-share-quality__segments" role="radiogroup" aria-label="Сценарий демонстрации">
      <label class="screen-share-quality__option"><input :checked="mode === 'motion'" type="radio" name="screen-share-mode" value="motion" @change="emit('update:mode', 'motion')"><span>Плавность — игры и видео</span></label>
      <label class="screen-share-quality__option"><input :checked="mode === 'text'" type="radio" name="screen-share-mode" value="text" @change="emit('update:mode', 'text')"><span>Текст — документы и код</span></label>
    </div>
  </fieldset>
  <details class="screen-share-quality__advanced" :open="advancedOpen">
    <summary>Дополнительные настройки качества</summary>
    <div class="screen-share-quality__advanced-options">
      <fieldset class="screen-share-quality__row"><legend>Максимальное разрешение</legend>
        <div class="screen-share-quality__segments" role="radiogroup" aria-label="Верхний предел разрешения трансляции">
          <label v-for="value in resolutions" :key="value" class="screen-share-quality__option" :title="mode === 'motion' && value === 1440 && !allow1440p60 ? '1440p60 пока недоступно без подтверждённой policy' : undefined"><input :checked="resolution === value" :disabled="mode === 'motion' && value === 1440 && !allow1440p60" type="radio" name="screen-share-resolution" :value="value" @change="emit('update:resolution', value)"><span>{{ value }}p</span></label>
        </div>
      </fieldset>
      <fieldset class="screen-share-quality__row"><legend>Частота кадров для {{ mode === 'motion' ? 'плавности' : 'текста' }}</legend>
        <div class="screen-share-quality__segments" role="radiogroup" :aria-label="`Частота кадров для ${mode === 'motion' ? 'плавности' : 'текста'}`">
          <label v-for="value in frameRates" :key="value" class="screen-share-quality__option"><input :checked="frameRate === value" type="radio" name="screen-share-frame-rate" :value="value" @change="emit('update:frameRate', value)"><span>{{ value }} FPS</span></label>
        </div>
      </fieldset>
      <p v-if="mode === 'motion' && resolution === 1440 && !allow1440p60" class="screen-share-quality__hint" role="status">1440p60 пока недоступно без подтверждённой policy.</p>
      <slot />
    </div>
  </details>
</template>
