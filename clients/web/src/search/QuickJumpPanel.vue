<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { buildQuickJumpEntries, type QuickJumpChannel, type QuickJumpPerson, type QuickJumpTarget } from './quick_jump'

const props = defineProps<{ channels: QuickJumpChannel[]; people: QuickJumpPerson[]; status: string }>()
const emit = defineEmits<{ select: [entry: QuickJumpTarget] }>()
const query = ref('')
const input = ref<HTMLInputElement | null>(null)
const entries = computed(() => buildQuickJumpEntries(query.value, props.channels, props.people))
onMounted(() => input.value?.focus())
</script>

<template>
  <section class="search-panel quick-jump-panel" aria-labelledby="quick-jump-title" data-testid="quick-jump-panel">
    <header class="search-panel-heading"><h1 id="quick-jump-title">Каналы и люди</h1></header>
    <label class="search-query-label"><span class="visually-hidden">Найти канал или человека</span><input ref="input" v-model="query" type="search" autocomplete="off" placeholder="Канал или имя человека"></label>
    <p v-if="status" class="search-status search-status--visible" role="status" aria-live="polite">{{ status }}</p>
    <ol v-else-if="entries.length" class="quick-jump-results" aria-label="Каналы и личные диалоги">
      <li v-for="entry in entries" :key="`${entry.kind}:${entry.id}`">
        <button type="button" :data-kind="entry.kind" @click="emit('select', { kind: entry.kind, id: entry.id })">
          <span>{{ entry.title }}</span><small>{{ entry.subtitle }}</small>
        </button>
      </li>
    </ol>
    <p v-else class="search-status search-status--visible" role="status">Совпадений нет.</p>
  </section>
</template>

<style scoped>
.quick-jump-results { display: grid; gap: 8px; list-style: none; margin: 16px 0; padding: 0; }
.quick-jump-results button { align-items: center; background: var(--gc-surface-raised, #20232d); border: 1px solid var(--gc-border, #363a46); border-radius: 8px; color: inherit; cursor: pointer; display: flex; justify-content: space-between; min-height: 44px; padding: 8px 12px; text-align: left; width: 100%; }
.quick-jump-results button:hover, .quick-jump-results button:focus-visible { border-color: var(--gc-accent, #6974f5); outline: 2px solid transparent; }
.quick-jump-results small { color: var(--gc-text-muted, #a2a6b4); }
</style>
