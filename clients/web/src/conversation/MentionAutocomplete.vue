<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { loadMembers, type GuildMember } from '../identity/profile_client'
import { addMentionId } from './mention_ids'
import { activeMentionQuery, replaceMentionQuery } from './mention_query'

const props = defineProps<{ modelValue: string; mentionUserIds: string[]; selfId: string; disabled: boolean; onlyParticipant?: { id: string; displayName: string } }>()
const emit = defineEmits<{ 'update:modelValue': [value: string]; 'update:mentionUserIds': [ids: string[]] }>()
const members = ref<GuildMember[]>([])
const loaded = ref(false)
const error = ref('')
const selectedIndex = ref(0)
const dismissed = ref(false)
const query = computed(() => activeMentionQuery(props.modelValue)?.query ?? '')
const candidates = computed(() => props.onlyParticipant ? [{ id: props.onlyParticipant.id, name: props.onlyParticipant.displayName }]
  : members.value.map(({ user_id, display_name }) => ({ id: user_id, name: display_name })))
const suggestions = computed(() => candidates.value.filter(({ id, name }) => id !== props.selfId && !props.mentionUserIds.includes(id) && name.toLocaleLowerCase('ru-RU').includes(query.value.toLocaleLowerCase('ru-RU'))))
watch(query, () => { selectedIndex.value = 0; dismissed.value = false })
watch(query, async (value) => {
  if (!value || props.onlyParticipant || loaded.value) return
  try { members.value = (await loadMembers()).members; loaded.value = true; error.value = '' }
  catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить участников.' }
}, { immediate: true })
function choose(id: string, name: string): void {
  if (props.disabled || !suggestions.value.some((item) => item.id === id)) return
  emit('update:modelValue', replaceMentionQuery(props.modelValue, name))
  emit('update:mentionUserIds', addMentionId(props.mentionUserIds, id, props.selfId))
}
function onKeydown(event: KeyboardEvent): void {
  if (!(event.target instanceof HTMLTextAreaElement) || event.target.id !== 'message-body' || dismissed.value || !query.value || !suggestions.value.length) return
  const count = Math.min(suggestions.value.length, 5)
  if (event.key === 'Escape') { dismissed.value = true; event.preventDefault(); event.stopPropagation() }
  if (event.key === 'ArrowDown') { selectedIndex.value = (selectedIndex.value + 1) % count; event.preventDefault() }
  if (event.key === 'ArrowUp') { selectedIndex.value = (selectedIndex.value + count - 1) % count; event.preventDefault() }
  if (event.key === 'Enter') { const member = suggestions.value[selectedIndex.value]; if (member) choose(member.id, member.name); event.preventDefault(); event.stopPropagation() }
}
onMounted(() => document.addEventListener('keydown', onKeydown, true))
onBeforeUnmount(() => document.removeEventListener('keydown', onKeydown, true))
</script>

<template>
  <div v-if="query && !dismissed && (suggestions.length || error)" class="mention-autocomplete">
    <ul v-if="suggestions.length" class="mention-popover" role="listbox" aria-label="Подсказки упоминаний">
      <li class="mention-popover-heading">Упомянуть участника</li>
      <li v-for="(member, index) in suggestions.slice(0, 5)" :key="member.id">
        <button type="button" role="option" :aria-selected="index === selectedIndex" :disabled="disabled" @mousedown.prevent="choose(member.id, member.name)"><span class="mention-popover-avatar" aria-hidden="true">{{ member.name.slice(0, 2).toLocaleUpperCase('ru-RU') }}</span><span class="mention-popover-member"><strong>{{ member.name }}</strong><small>@{{ member.name.toLocaleLowerCase('ru-RU') }}</small></span><kbd v-if="index === selectedIndex">Enter</kbd></button>
      </li>
      <li class="mention-popover-help">↑ ↓ — выбрать · Enter — вставить · Esc — закрыть</li>
    </ul>
    <p v-if="error" class="mention-autocomplete-error" role="alert">{{ error }}</p>
  </div>
</template>
