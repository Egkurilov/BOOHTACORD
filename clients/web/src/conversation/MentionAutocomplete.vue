<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { loadMembers, type GuildMember } from '../identity/profile_client'
import { addMentionId } from './mention_ids'
import { activeMentionQuery, replaceMentionQuery } from './mention_query'
import { canHandleMentionKeydown, isMentionComposerTarget } from './mention_keyboard'

const props = defineProps<{ modelValue: string; mentionUserIds: string[]; selfId: string; disabled: boolean; onlyParticipant?: { id: string; displayName: string } }>()
const emit = defineEmits<{ 'update:modelValue': [value: string]; 'update:mentionUserIds': [ids: string[]] }>()
const members = ref<GuildMember[]>([])
const loaded = ref(false)
const loading = ref(false)
const error = ref('')
const selectedIndex = ref(0)
const dismissed = ref(false)
const compositionActive = ref(false)
let requestVersion = 0
const active = computed(() => activeMentionQuery(props.modelValue) !== null)
const query = computed(() => activeMentionQuery(props.modelValue)?.query ?? '')
const candidates = computed(() => props.onlyParticipant ? [{ id: props.onlyParticipant.id, name: props.onlyParticipant.displayName, login: undefined as string | undefined }]
  : members.value.map(({ user_id, display_name, login }) => ({ id: user_id, name: display_name, login })))
const suggestions = computed(() => candidates.value.filter(({ id, name, login }) => id !== props.selfId && `${name} ${login}`.toLocaleLowerCase('ru-RU').includes(query.value.toLocaleLowerCase('ru-RU'))))
watch(() => props.modelValue, () => { selectedIndex.value = 0; dismissed.value = false })
watch(() => props.selfId, () => { requestVersion += 1; members.value = []; loaded.value = false; loading.value = false; if (active.value) void load() })
async function load(): Promise<void> {
  if (!active.value || props.onlyParticipant || loaded.value || loading.value) return
  const version = requestVersion
  loading.value = true; error.value = ''
  try {
    const next: GuildMember[] = []
    let cursor: string | undefined
    let pages = 0
    do {
      const page = await loadMembers(cursor)
      next.push(...page.members)
      cursor = page.next_cursor
      pages += 1
    } while (cursor && next.length < 100 && pages < 10)
    if (version === requestVersion) { members.value = next; loaded.value = true }
  } catch (cause) { if (version === requestVersion) error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить участников.' }
  finally { if (version === requestVersion) loading.value = false }
}
watch(active, (value) => { if (value) void load(); else dismissed.value = false }, { immediate: true })
function choose(id: string, name: string): void {
  if (props.disabled || compositionActive.value || !suggestions.value.some((item) => item.id === id)) return
  emit('update:modelValue', replaceMentionQuery(props.modelValue, name))
  emit('update:mentionUserIds', addMentionId(props.mentionUserIds, id, props.selfId))
}
function onKeydown(event: KeyboardEvent): void {
  if (!canHandleMentionKeydown(event, compositionActive.value) || dismissed.value || !active.value || !suggestions.value.length) return
  const count = Math.min(suggestions.value.length, 5)
  if (event.key === 'Escape') { dismissed.value = true; event.preventDefault(); event.stopPropagation() }
  if (event.key === 'ArrowDown') { selectedIndex.value = (selectedIndex.value + 1) % count; event.preventDefault() }
  if (event.key === 'ArrowUp') { selectedIndex.value = (selectedIndex.value + count - 1) % count; event.preventDefault() }
  if (event.key === 'Enter') { const member = suggestions.value[selectedIndex.value]; if (member) choose(member.id, member.name); event.preventDefault(); event.stopPropagation() }
}
function onCompositionStart(event: CompositionEvent): void {
  if (isMentionComposerTarget(event.target)) compositionActive.value = true
}
function onCompositionEnd(event: CompositionEvent): void {
  if (isMentionComposerTarget(event.target)) compositionActive.value = false
}
onMounted(() => {
  document.addEventListener('keydown', onKeydown, true)
  document.addEventListener('compositionstart', onCompositionStart, true)
  document.addEventListener('compositionend', onCompositionEnd, true)
})
onBeforeUnmount(() => {
  document.removeEventListener('keydown', onKeydown, true)
  document.removeEventListener('compositionstart', onCompositionStart, true)
  document.removeEventListener('compositionend', onCompositionEnd, true)
})
</script>

<template>
  <div v-if="active && !compositionActive && !dismissed && (suggestions.length || error || loading)" class="mention-autocomplete" :class="{ 'mention-autocomplete--unfiltered': !query }">
    <p v-if="loading" class="mention-autocomplete-loading" role="status">Загружаем участников…</p>
    <ul v-if="suggestions.length" class="mention-popover" role="listbox" aria-label="Подсказки упоминаний">
      <li class="mention-popover-heading">Упомянуть участника</li>
      <li v-for="(member, index) in suggestions.slice(0, 5)" :key="member.id">
        <button type="button" role="option" :aria-selected="index === selectedIndex" :disabled="disabled" @mousedown.prevent="choose(member.id, member.name)" @click="choose(member.id, member.name)"><span class="mention-popover-avatar" aria-hidden="true">{{ member.name.slice(0, 2).toLocaleUpperCase('ru-RU') }}</span><span class="mention-popover-member"><strong>{{ member.name }}</strong><small v-if="member.login">@{{ member.login }}</small></span><kbd v-if="index === selectedIndex">Enter</kbd></button>
      </li>
      <li class="mention-popover-help">↑ ↓ — выбрать · Enter — вставить · Esc — закрыть</li>
    </ul>
    <p v-if="error" class="mention-autocomplete-error" role="alert">{{ error }} <button type="button" @click="load">Повторить</button></p>
  </div>
</template>
