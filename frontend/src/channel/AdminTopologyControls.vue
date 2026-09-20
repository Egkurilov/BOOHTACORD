<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { createCategory, createChannel, deleteEmptyCategory } from './admin_topology_client'
import type { ChannelKind, TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number }>()
const emit = defineEmits<{ changed: [] }>()

const categoryName = ref('')
const channelName = ref('')
const channelKind = ref<ChannelKind>('VOICE')
const selectedCategoryId = ref('')
const pending = ref(false)
const error = ref<string | null>(null)
const status = ref<string | null>(null)
const selectedCategoryExists = computed(() => props.categories.some((category) => category.id === selectedCategoryId.value))
const selectedCategory = computed(() => props.categories.find((category) => category.id === selectedCategoryId.value))
const selectedCategoryEmpty = computed(() => selectedCategory.value?.channels.length === 0)

watch(() => props.categories, (categories) => {
  if (!categories.some((category) => category.id === selectedCategoryId.value)) {
    selectedCategoryId.value = categories[0]?.id ?? ''
  }
}, { immediate: true })

function resetFeedback(): void {
  error.value = null
  status.value = null
}

async function submitCategory(): Promise<void> {
  resetFeedback()
  if (!categoryName.value.trim()) {
    error.value = 'Введите имя категории.'
    return
  }

  pending.value = true
  try {
    const category = await createCategory({ name: categoryName.value })
    categoryName.value = ''
    selectedCategoryId.value = category.id
    status.value = 'Категория создана. Топология обновляется.'
    emit('changed')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'Не удалось создать категорию.'
  } finally {
    pending.value = false
  }
}

async function submitChannel(): Promise<void> {
  resetFeedback()
  if (!selectedCategoryExists.value) {
    error.value = 'Сначала выберите категорию.'
    return
  }
  if (!channelName.value.trim()) {
    error.value = 'Введите имя канала.'
    return
  }

  pending.value = true
  try {
    await createChannel(selectedCategoryId.value, { name: channelName.value, kind: channelKind.value })
    channelName.value = ''
    status.value = 'Канал создан. Топология обновляется.'
    emit('changed')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'Не удалось создать канал.'
  } finally {
    pending.value = false
  }
}

async function removeSelectedCategory(): Promise<void> {
  resetFeedback()
  if (!selectedCategory.value || !selectedCategoryEmpty.value || !window.confirm(`Удалить пустую категорию «${selectedCategory.value.name}»?`)) return
  pending.value = true
  try {
    await deleteEmptyCategory(selectedCategory.value.id, props.revision)
    status.value = 'Пустая категория удалена. Топология обновляется.'
    emit('changed')
  } catch (cause) {
    error.value = cause instanceof Error ? cause.message : 'Не удалось удалить категорию.'
  } finally { pending.value = false }
}
</script>

<template>
  <section class="admin-topology-controls" aria-labelledby="admin-topology-title">
    <h2 id="admin-topology-title">Управление каналами</h2>
    <form class="admin-topology-form" @submit.prevent="submitCategory">
      <label>
        Новая категория
        <input v-model="categoryName" :disabled="pending" maxlength="80" name="category-name" required>
      </label>
      <button type="submit" :disabled="pending">Создать категорию</button>
    </form>
    <form class="admin-topology-form" @submit.prevent="submitChannel">
      <label>
        Категория
        <select v-model="selectedCategoryId" :disabled="pending || props.categories.length === 0" name="channel-category">
          <option v-for="category in props.categories" :key="category.id" :value="category.id">{{ category.name }}</option>
        </select>
      </label>
      <label>
        Новый канал
        <input v-model="channelName" :disabled="pending || !selectedCategoryExists" maxlength="80" name="channel-name" required>
      </label>
      <label>
        Тип канала
        <select v-model="channelKind" :disabled="pending || !selectedCategoryExists" name="channel-kind">
          <option value="VOICE">Голосовой</option>
          <option value="TEXT">Текстовый</option>
        </select>
      </label>
      <button type="submit" :disabled="pending || !selectedCategoryExists">Создать канал</button>
    </form>
    <button type="button" :disabled="pending || !selectedCategoryEmpty" @click="removeSelectedCategory">Удалить пустую категорию</button>
    <p v-if="status" class="admin-topology-status" aria-live="polite">{{ status }}</p>
    <p v-if="error" class="admin-topology-error" role="alert">{{ error }}</p>
  </section>
</template>
