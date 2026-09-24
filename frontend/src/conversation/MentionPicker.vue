<script setup lang="ts">
import { computed, ref } from 'vue'

import { useAuthorDirectory } from '../identity/author_directory'
import { loadMembers, type GuildMember } from '../identity/profile_client'
import { addMentionId } from './mention_ids'

const props = defineProps<{ modelValue: string[]; selfId: string; disabled: boolean; onlyParticipant?: { id: string; displayName: string } }>()
const emit = defineEmits<{ 'update:modelValue': [ids: string[]] }>()
const authors = useAuthorDirectory()
const members = ref<GuildMember[]>([])
const loaded = ref(false)
const loading = ref(false)
const nextCursor = ref<string | undefined>()
const error = ref<string | null>(null)
const candidateId = ref('')
const candidates = computed(() => props.onlyParticipant ? [{ id: props.onlyParticipant.id, name: props.onlyParticipant.displayName }]
  : members.value.map(({ user_id, display_name }) => ({ id: user_id, name: display_name })))
const available = computed(() => candidates.value.filter(({ id }) => id !== props.selfId && !props.modelValue.includes(id)))

function label(id: string): string { return candidates.value.find((member) => member.id === id)?.name ?? authors.displayName(id) }
function add(): void {
  if (!available.value.some(({ id }) => id === candidateId.value)) return
  emit('update:modelValue', addMentionId(props.modelValue, candidateId.value, props.selfId))
  candidateId.value = ''
}
function remove(id: string): void { emit('update:modelValue', props.modelValue.filter((selected) => selected !== id)) }

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
  <div class="mention-picker" role="group" aria-label="Упоминания">
    <span class="mention-picker-title">Упоминания</span>
    <span v-for="id in modelValue" :key="id" class="mention-chip">@{{ label(id) }} <button type="button" :disabled="disabled" :aria-label="`Убрать упоминание ${label(id)}`" @click="remove(id)">×</button></span>
    <button v-if="!onlyParticipant && (!loaded || nextCursor)" type="button" :disabled="disabled || loading" @click="loadNext">{{ loading ? 'Загружаем…' : loaded ? 'Показать ещё участников' : 'Загрузить участников' }}</button>
    <label v-if="available.length" class="mention-picker-choice">Участник
      <select v-model="candidateId" :disabled="disabled" name="mention-recipient"><option value="">Выберите участника</option><option v-for="member in available" :key="member.id" :value="member.id">{{ member.name }}</option></select>
    </label>
    <button v-if="available.length" type="button" :disabled="disabled || !candidateId || modelValue.length >= 100" @click="add">Упомянуть</button>
    <p v-if="error" class="state state-error" role="alert">{{ error }}</p>
  </div>
</template>
