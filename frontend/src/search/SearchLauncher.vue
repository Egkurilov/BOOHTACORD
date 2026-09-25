<script setup lang="ts">
import { nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { shouldOpenSearchShortcut } from './search_shortcut'

const props = defineProps<{ active: boolean }>()
const emit = defineEmits<{ open: []; close: [] }>()
const trigger = ref<HTMLButtonElement | null>(null)
let returnFocus: HTMLElement | null = null
function openSearch(): void { returnFocus = document.activeElement as HTMLElement | null; emit('open') }
function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape' && props.active) { emit('close'); return }
  if (shouldOpenSearchShortcut(event)) { event.preventDefault(); openSearch() }
}
watch(() => props.active, (active, wasActive) => { if (wasActive && !active) void nextTick(() => { (returnFocus?.isConnected ? returnFocus : trigger.value)?.focus(); returnFocus = null }) })
onMounted(() => window.addEventListener('keydown', onKeydown))
onBeforeUnmount(() => window.removeEventListener('keydown', onKeydown))
</script>

<template>
  <button ref="trigger" class="guild-search-button" type="button" :aria-expanded="active" aria-controls="search-aside-panel" aria-keyshortcuts="Control+K Meta+K" @click="active ? emit('close') : openSearch()"><span aria-hidden="true">⌕</span><span>Поиск сообщений</span><kbd>Ctrl K</kbd></button>
</template>
