<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue'
import { emojiCatalog, mergeEmojiNames, quickEmoji, searchEmoji, updateRecentEmoji, type EmojiEntry } from './emoji_catalog'

defineProps<{ disabled?: boolean }>()
const emit = defineEmits<{ select: [emoji: string]; close: [] }>()
const root = ref<HTMLElement | null>(null)
const menu = ref<HTMLElement | null>(null)
const trigger = ref<HTMLButtonElement | null>(null)
const search = ref<HTMLInputElement | null>(null)
const open = ref(false)
const expanded = ref(false)
const query = ref('')
const recent = ref<string[]>([])
const allEntries = ref<EmojiEntry[]>(emojiCatalog)
const visibleCount = ref(120)
const catalog = computed(() => new Map(allEntries.value.map((entry) => [entry.emoji, entry])))
const matches = computed(() => searchEmoji(query.value, allEntries.value))
const visibleMatches = computed(() => matches.value.slice(0, visibleCount.value))
const recentEntries = computed(() => recent.value.map((emoji) => catalog.value.get(emoji)).filter((entry) => entry !== undefined))

function choose(emoji: string): void {
  recent.value = updateRecentEmoji(recent.value, emoji)
  try { localStorage.setItem('boohtacord-recent-emoji', JSON.stringify(recent.value)) } catch { /* storage may be unavailable */ }
  open.value = false
  emit('select', emoji)
}
function close(): void { open.value = false; emit('close') }
async function show(): Promise<void> {
  open.value = true
  expanded.value = false
  query.value = ''
  await nextTick()
  menu.value?.querySelector<HTMLButtonElement>('button[data-emoji]')?.focus()
}
function toggle(): void { if (open.value) close(); else void show() }
async function expand(): Promise<void> {
  expanded.value = true
  await nextTick()
  search.value?.focus()
  const { default: entries } = await import('./emoji_full_catalog.json')
  allEntries.value = mergeEmojiNames(entries)
}
function onKeydown(event: KeyboardEvent): void {
  if (event.key === 'Escape') { event.preventDefault(); close(); trigger.value?.focus(); return }
  if (event.target instanceof HTMLInputElement || !['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End'].includes(event.key)) return
  const buttons = [...(menu.value?.querySelectorAll<HTMLButtonElement>('button[data-emoji]') ?? [])]
  const index = buttons.indexOf(document.activeElement as HTMLButtonElement)
  const next = event.key === 'Home' ? 0 : event.key === 'End' ? buttons.length - 1 : index + ({ ArrowLeft: -1, ArrowRight: 1, ArrowUp: -6, ArrowDown: 6 }[event.key] ?? 0)
  if (buttons.length) buttons[Math.max(0, Math.min(buttons.length - 1, next))]?.focus()
  event.preventDefault()
}
function onOutside(event: PointerEvent): void { if (open.value && event.target instanceof Node && !root.value?.contains(event.target)) open.value = false }
onMounted(() => {
  try {
    const stored: unknown = JSON.parse(localStorage.getItem('boohtacord-recent-emoji') ?? '[]')
    if (Array.isArray(stored)) recent.value = stored.filter((emoji): emoji is string => typeof emoji === 'string' && emoji.length <= 16).slice(0, 12)
  } catch { /* storage may be unavailable */ }
  document.addEventListener('pointerdown', onOutside)
})
onBeforeUnmount(() => document.removeEventListener('pointerdown', onOutside))
defineExpose({ show })
</script>

<template>
  <span ref="root" class="emoji-picker">
    <button ref="trigger" class="emoji-trigger" type="button" aria-label="Добавить emoji" :aria-expanded="open" :disabled="disabled" @click="toggle"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M8 14a4 4 0 0 0 8 0M8 8h.01M16 8h.01"/></svg></button>
    <div v-if="open" ref="menu" class="emoji-menu" role="dialog" aria-label="Выбор emoji" @keydown="onKeydown">
      <div class="emoji-quick" role="group" aria-label="Быстрые emoji">
        <button v-for="emoji in quickEmoji" :key="emoji" type="button" data-emoji :aria-label="`Добавить ${emoji}`" @click="choose(emoji)">{{ emoji }}</button>
      </div>
      <button v-if="!expanded" class="emoji-expand" type="button" @click="expand">Все emoji</button>
      <template v-else>
        <label class="emoji-search">Поиск emoji<input ref="search" v-model="query" type="search" placeholder="Название или символ"></label>
        <div v-if="recentEntries.length && !query" class="emoji-recent"><strong>Недавние</strong><div class="emoji-grid">
          <button v-for="entry in recentEntries" :key="entry.emoji" type="button" data-emoji :aria-label="entry.name" :title="entry.name" @click="choose(entry.emoji)">{{ entry.emoji }}</button>
        </div></div>
        <div class="emoji-results" role="group" aria-label="Все emoji"><div class="emoji-grid">
          <button v-for="entry in visibleMatches" :key="entry.emoji" type="button" data-emoji :aria-label="entry.name" :title="entry.name" @click="choose(entry.emoji)">{{ entry.emoji }}</button>
        </div><button v-if="matches.length > visibleCount" class="emoji-more" type="button" @click="visibleCount += 120">Показать ещё</button><p v-if="!matches.length">Совпадений нет.</p></div>
      </template>
    </div>
  </span>
</template>
