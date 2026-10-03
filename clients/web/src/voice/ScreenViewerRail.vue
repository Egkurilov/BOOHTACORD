<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue'
import { avatarBackground } from '../design/avatar_color'
import type { ScreenViewerCard } from './screen_viewer_controller'
import { observeHorizontalOverflow } from './screen_rail_overflow'

defineProps<{ cards: ScreenViewerCard[]; selectedId: string | null; participantCount: number }>()
const emit = defineEmits<{ select: [id: string]; returnVoice: [] }>()
const rail = ref<HTMLDivElement | null>(null)
const hasOverflow = ref(false)
let stopObserving: (() => void) | null = null
watch(rail, (element) => {
  stopObserving?.()
  stopObserving = element ? observeHorizontalOverflow(element, (visible) => { hasOverflow.value = visible }) : null
}, { flush: 'post' })
onBeforeUnmount(() => stopObserving?.())
const initials = (name: string) => name.trim().slice(0, 2).toLocaleUpperCase('ru-RU') || 'У'
</script>

<template>
  <section class="screen-rail-section" aria-label="Демонстрации в канале">
    <div ref="rail" class="screen-cards stream-rail" :class="{ 'has-overflow': hasOverflow }" data-testid="stream-rail" aria-label="Выбор демонстрации" :aria-description="hasOverflow ? 'Есть ещё демонстрации справа. Прокрутите список по горизонтали.' : undefined">
      <button v-for="stream in cards" :key="stream.id" data-testid="stream-select" class="screen-card stream-option" :class="{ selected: stream.id === selectedId }" type="button" :aria-pressed="stream.id === selectedId" @click="emit('select', stream.id)">
        <span class="stream-card-preview"><img v-if="stream.thumbnailUrl" class="stream-thumbnail" :src="stream.thumbnailUrl" alt=""><span v-else class="stream-avatar" :style="{ backgroundColor: avatarBackground(stream.accountId ?? stream.participantId) }" aria-hidden="true">{{ initials(stream.participantName) }}</span></span>
        <span class="stream-option-copy"><span>{{ stream.isLocal ? 'Ваш экран' : `Экран ${stream.participantName || 'участника'}` }}</span><b v-if="stream.id === selectedId">ЭФИР</b></span>
      </button>
      <button class="screen-card stream-option stream-rail-participants" type="button" @click="emit('returnVoice')"><span class="stream-card-preview"><span class="stream-avatar" aria-hidden="true">ДА</span></span><span class="stream-option-copy">Участники · {{ participantCount }}</span></button>
    </div>
  </section>
</template>
