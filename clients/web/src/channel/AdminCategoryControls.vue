<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'

import { createCategory, deleteEmptyCategory } from './admin_topology_client'
import AdminConfirmation from './AdminConfirmation.vue'
import { createCategoryEditor } from './category_editor'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number; selectedCategoryId: string }>()
const emit = defineEmits<{ changed: []; 'update:selectedCategoryId': [id: string] }>()
const selected = computed(() => props.categories.find(({ id }) => id === props.selectedCategoryId))
const editor = createCategoryEditor(() => ({ categories: props.categories, revision: props.revision, selectedCategoryId: props.selectedCategoryId }), () => emit('changed'))
const newName = ref('')
const confirmation = ref<{ ask: (message: string) => Promise<boolean> } | null>(null)
const mutating = ref(false)
const localError = ref<string | null>(null)
const localStatus = ref<string | null>(null)
const errorNode = ref<HTMLElement | null>(null)
const statusNode = ref<HTMLElement | null>(null)
const errorText = computed(() => editor.error.value ?? localError.value)
const statusText = computed(() => editor.status.value ?? localStatus.value)
const busy = computed(() => mutating.value || editor.pending.value || editor.needsRefresh.value)

watch(() => [props.categories, props.revision, props.selectedCategoryId], editor.sync, { immediate: true })
watch(errorText, async (message) => { if (message) { await nextTick(); errorNode.value?.focus() } })
watch(statusText, async (message) => { if (message) { await nextTick(); statusNode.value?.focus() } })

function changeSelection(event: Event): void { emit('update:selectedCategoryId', (event.target as HTMLSelectElement).value) }
function changeRename(event: Event): void { editor.setRenameDraft((event.target as HTMLInputElement).value) }
function resetFeedback(): void { localError.value = null; localStatus.value = null; editor.error.value = null; editor.status.value = null }
function rename(): void { resetFeedback(); void editor.rename() }
function move(direction: -1 | 1): void { resetFeedback(); void editor.move(direction) }

async function create(): Promise<void> {
  resetFeedback()
  if (!newName.value.trim() || !validCodePointLength(newName.value, 1, 80)) { localError.value = 'Введите название раздела до 80 символов.'; return }
  mutating.value = true
  try {
    const category = await createCategory({ name: newName.value })
    newName.value = ''
    emit('update:selectedCategoryId', category.id)
    localStatus.value = 'Категория создана. Обновляем список.'
    emit('changed')
  } catch (cause) { localError.value = cause instanceof Error ? cause.message : 'Не удалось создать категорию.' }
  finally { mutating.value = false }
}

async function remove(): Promise<void> {
  if (!selected.value || selected.value.channels.length || !await confirmation.value?.ask(`Удалить пустой раздел «${selected.value.name}»?`)) return
  resetFeedback()
  mutating.value = true
  try {
    await deleteEmptyCategory(selected.value.id, props.revision)
    localStatus.value = 'Пустая категория удалена. Обновляем список.'
    emit('changed')
  } catch (cause) {
    localError.value = cause instanceof Error ? cause.message : 'Не удалось удалить категорию.'
    emit('changed')
  } finally { mutating.value = false }
}
</script>

<template>
  <div class="admin-category-controls">
    <AdminConfirmation ref="confirmation" id="admin-category-delete-confirm" title="Удалить раздел" confirm-label="Удалить раздел" />
    <form class="admin-topology-form" @submit.prevent="create">
      <label>Новый раздел<input v-model="newName" :disabled="busy" name="category-name" required :aria-describedby="editor.error.value || localError ? 'category-error' : undefined"></label>
      <button type="submit" :disabled="busy">Создать категорию</button>
    </form>
    <form class="admin-topology-form admin-topology-form--rename" @submit.prevent="rename">
      <label>Раздел
        <select :value="selectedCategoryId" :disabled="busy || !categories.length" name="edit-category" @change="changeSelection">
          <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.name }}</option>
        </select>
      </label>
      <label>Новое название раздела
        <input :value="editor.renameDraft.value" :disabled="busy || !selected" name="rename-category" required :aria-describedby="editor.error.value || localError ? 'category-error' : undefined" @input="changeRename">
      </label>
      <button type="submit" :disabled="busy || !selected">Переименовать категорию</button>
    </form>
    <div class="admin-category-order" role="group" aria-label="Порядок категорий">
      <button type="button" :disabled="busy || !editor.canMove(-1)" :aria-label="`Переместить раздел «${selected?.name ?? ''}» выше`" @click="move(-1)">Выше</button>
      <button type="button" :disabled="busy || !editor.canMove(1)" :aria-label="`Переместить раздел «${selected?.name ?? ''}» ниже`" @click="move(1)">Ниже</button>
    </div>
    <button type="button" :disabled="busy || !selected || selected.channels.length > 0" @click="remove">Удалить пустой раздел</button>
    <button v-if="editor.needsRefresh.value" type="button" @click="emit('changed')">Повторить обновление списка</button>
    <p v-show="statusText" id="category-status" ref="statusNode" class="admin-topology-status" role="status" tabindex="-1">{{ statusText }}</p>
    <p v-show="errorText" id="category-error" ref="errorNode" class="admin-topology-error" role="alert" tabindex="-1">{{ errorText }}</p>
  </div>
</template>
