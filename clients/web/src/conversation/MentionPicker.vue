<script setup lang="ts">
import { computed, nextTick, ref, useId } from 'vue'

import { useAuthorDirectory } from '../identity/author_directory'
import { loadMembers, type GuildMember } from '../identity/profile_client'
import { addMentionId } from './mention_ids'

const props = defineProps<{ modelValue: string[]; selfId: string; disabled: boolean; quick?: boolean; onlyParticipant?: { id: string; displayName: string } }>()
const emit = defineEmits<{ 'update:modelValue': [ids: string[]]; activate: [] }>()
const authors = useAuthorDirectory()
const members = ref<GuildMember[]>([])
const loaded = ref(false)
const loading = ref(false)
const nextCursor = ref<string | undefined>()
const error = ref<string | null>(null)
const candidateId = ref('')
const expanded = ref(false)
const disclosure = ref<HTMLButtonElement | null>(null)
const controlsId = useId()
const candidates = computed(() => props.onlyParticipant ? [{ id: props.onlyParticipant.id, name: props.onlyParticipant.displayName }]
  : members.value.map(({ user_id, display_name }) => ({ id: user_id, name: display_name })))
const available = computed(() => candidates.value.filter(({ id }) => id !== props.selfId && !props.modelValue.includes(id)))

function label(id: string): string { return candidates.value.find((member) => member.id === id)?.name ?? authors.displayName(id) }
function add(): void {
  if (!available.value.some(({ id }) => id === candidateId.value)) return
  const lastCandidate = available.value.length === 1
  emit('update:modelValue', addMentionId(props.modelValue, candidateId.value, props.selfId))
  candidateId.value = ''
  if (lastCandidate) void nextTick(() => disclosure.value?.focus())
}
function remove(id: string): void {
  emit('update:modelValue', props.modelValue.filter((selected) => selected !== id))
  void nextTick(() => disclosure.value?.focus())
}
function close(): void {
  expanded.value = false
  void nextTick(() => disclosure.value?.focus())
}
function onTrigger(): void {
  if (props.quick) { emit('activate'); return }
  expanded.value = !expanded.value
}

async function loadNext(): Promise<void> {
  if (loading.value || props.onlyParticipant || !props.selfId) return
  loading.value = true
  error.value = null
  try {
    const page = await loadMembers(nextCursor.value)
    members.value = [...members.value, ...page.members.filter((member) => !members.value.some(({ user_id }) => user_id === member.user_id))]
    nextCursor.value = page.next_cursor
    loaded.value = true
  } catch (cause) { error.value = cause instanceof Error ? cause.message : 'Не удалось загрузить участников.' }
  finally { loading.value = false }
}
</script>

<template>
  <div class="mention-picker" :class="{ 'mention-picker--expanded': expanded }" role="group" aria-label="Упоминания">
    <button ref="disclosure" class="mention-picker-trigger" type="button" :disabled="disabled" :aria-label="expanded ? 'Скрыть выбор упоминания' : 'Выбрать упоминание'" :aria-expanded="quick ? undefined : expanded" :aria-controls="quick ? undefined : controlsId" @click="onTrigger"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="12" r="4"/><path d="M16 8v6a2 2 0 0 0 4 0v-2a8 8 0 1 0-3 6"/></svg></button>
    <span v-for="id in modelValue" :key="id" class="mention-chip">@{{ label(id) }} <button type="button" :disabled="disabled" :aria-label="`Убрать упоминание ${label(id)}`" @click="remove(id)">×</button></span>
    <div v-if="!quick" :id="controlsId" class="mention-picker-controls" :hidden="!expanded" @keydown.esc.stop="close">
      <button v-if="!onlyParticipant && (!loaded || nextCursor)" type="button" :disabled="disabled || loading" @click="loadNext">{{ loading ? 'Загружаем…' : loaded ? 'Показать ещё участников' : 'Загрузить участников' }}</button>
      <label v-if="available.length" class="mention-picker-choice">Участник
        <select v-model="candidateId" :disabled="disabled" name="mention-recipient"><option value="">Выберите участника</option><option v-for="member in available" :key="member.id" :value="member.id">{{ member.name }}</option></select>
      </label>
      <button v-if="available.length" type="button" :disabled="disabled || !candidateId || modelValue.length >= 100" @click="add">Упомянуть</button>
      <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
    </div>
  </div>
</template>
