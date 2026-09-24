<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { validCodePointLength } from '../validation/unicode_limits/unicode_limits'

import { createCategory, deleteEmptyCategory } from './admin_topology_client'
import { createCategoryEditor } from './category_editor'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number; selectedCategoryId: string }>()
const emit = defineEmits<{ changed: []; 'update:selectedCategoryId': [id: string] }>()
const selected = computed(() => props.categories.find(({ id }) => id === props.selectedCategoryId))
const editor = createCategoryEditor(() => ({ categories: props.categories, revision: props.revision, selectedCategoryId: props.selectedCategoryId }), () => emit('changed'))
const newName = ref('')
const mutating = ref(false)
const localError = ref<string | null>(null)
const localStatus = ref<string | null>(null)
const busy = computed(() => mutating.value || editor.pending.value || editor.needsRefresh.value)

watch(() => [props.categories, props.revision, props.selectedCategoryId], editor.sync, { immediate: true })

function changeSelection(event: Event): void { emit('update:selectedCategoryId', (event.target as HTMLSelectElement).value) }
function changeRename(event: Event): void { editor.setRenameDraft((event.target as HTMLInputElement).value) }

async function create(): Promise<void> {
  localError.value = null
  localStatus.value = null
  if (!newName.value.trim() || !validCodePointLength(newName.value, 1, 80)) { localError.value = 'Введите имя категории до 80 символов.'; return }
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
  if (!selected.value || selected.value.channels.length || !window.confirm(`Удалить пустую категорию «${selected.value.name}»?`)) return
  localError.value = null
  localStatus.value = null
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
    <form class="admin-topology-form" @submit.prevent="create">
      <label>Новая категория<input v-model="newName" :disabled="busy" name="category-name" required :aria-describedby="editor.error.value || localError ? 'category-error' : undefined"></label>
      <button type="submit" :disabled="busy">Создать категорию</button>
    </form>
    <form class="admin-topology-form admin-topology-form--rename" @submit.prevent="editor.rename">
      <label>Категория
        <select :value="selectedCategoryId" :disabled="busy || !categories.length" name="edit-category" @change="changeSelection">
          <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.name }}</option>
        </select>
      </label>
      <label>Новое имя категории
        <input :value="editor.renameDraft.value" :disabled="busy || !selected" name="rename-category" required :aria-describedby="editor.error.value || localError ? 'category-error' : undefined" @input="changeRename">
      </label>
      <button type="submit" :disabled="busy || !selected">Переименовать категорию</button>
    </form>
    <div class="admin-category-order" role="group" aria-label="Порядок категорий">
      <button type="button" :disabled="busy || !editor.canMove(-1)" :aria-label="`Переместить категорию «${selected?.name ?? ''}» выше`" @click="editor.move(-1)">Выше</button>
      <button type="button" :disabled="busy || !editor.canMove(1)" :aria-label="`Переместить категорию «${selected?.name ?? ''}» ниже`" @click="editor.move(1)">Ниже</button>
    </div>
    <button type="button" :disabled="busy || !selected || selected.channels.length > 0" @click="remove">Удалить пустую категорию</button>
    <button v-if="editor.needsRefresh.value" type="button" @click="emit('changed')">Повторить обновление списка</button>
    <p v-if="editor.status.value || localStatus" class="admin-topology-status" aria-live="polite">{{ editor.status.value ?? localStatus }}</p>
    <p v-if="editor.error.value || localError" id="category-error" class="admin-topology-error" role="alert">{{ editor.error.value ?? localError }}</p>
  </div>
</template>
