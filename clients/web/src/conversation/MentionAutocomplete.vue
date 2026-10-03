<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { loadMembers, type GuildMember } from '../identity/profile_client'
import { addMentionId } from './mention_ids'
import { activeMentionQuery, replaceMentionQuery } from './mention_query'

const props = defineProps<{ modelValue: string; mentionUserIds: string[]; selfId: string; disabled: boolean; onlyParticipant?: { id: string; displayName: string } }>()
const emit = defineEmits<{ 'update:modelValue': [value: string]; 'update:mentionUserIds': [ids: string[]] }>()
const members = ref<GuildMember[]>([])
const loaded = ref(false)
const error = ref('')
const query = computed(() => activeMentionQuery(props.modelValue)?.query ?? '')
const candidates = computed(() => props.onlyParticipant ? [{ id: props.onlyParticipant.id, name: props.onlyParticipant.displayName }]
  : members.value.map(({ user_id, display_name }) => ({ id: user_id, name: display_name })))
const suggestions = computed(() => candidates.value.filter(({ id, name }) => id !== props.selfId && !props.mentionUserIds.includes(id) && name.toLocaleLowerCase('ru-RU').includes(query.value.toLocaleLowerCase('ru-RU'))))
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
</script>

<template>
  <div v-if="query && (suggestions.length || error)" class="mention-autocomplete">
    <ul v-if="suggestions.length" class="mention-popover" role="listbox" aria-label="Подсказки упоминаний">
      <li v-for="member in suggestions.slice(0, 5)" :key="member.id">
        <button type="button" role="option" :disabled="disabled" @mousedown.prevent="choose(member.id, member.name)">@{{ member.name }}</button>
      </li>
    </ul>
    <p v-if="error" class="mention-autocomplete-error" role="alert">{{ error }}</p>
  </div>
</template>
