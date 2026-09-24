<script setup lang="ts">
import { computed, ref, watch } from 'vue'

import { createChannel } from './admin_topology_client'
import AdminCategoryControls from './AdminCategoryControls.vue'
import AdminChannelRename from './AdminChannelRename.vue'
import AdminChannelMove from './AdminChannelMove.vue'
import AdminChannelOrder from './AdminChannelOrder.vue'
import AdminTextArchive from './AdminTextArchive.vue'
import AdminVoiceClose from './AdminVoiceClose.vue'
import type { ChannelKind, TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number }>()
const emit = defineEmits<{ changed: [] }>()

const channelName = ref('')
const channelKind = ref<ChannelKind>('VOICE')
const selectedCategoryId = ref('')
const pending = ref(false)
const error = ref<string | null>(null)
const status = ref<string | null>(null)
const selectedCategoryExists = computed(() => props.categories.some((category) => category.id === selectedCategoryId.value))

watch(() => props.categories, (categories) => {
  if (!categories.some((category) => category.id === selectedCategoryId.value)) {
    selectedCategoryId.value = categories[0]?.id ?? ''
  }
}, { immediate: true })

function resetFeedback(): void {
  error.value = null
  status.value = null
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

</script>

<template>
  <section class="admin-topology-controls" aria-labelledby="admin-topology-title">
    <h2 id="admin-topology-title">Управление каналами</h2>
    <AdminCategoryControls :categories="props.categories" :revision="props.revision" :selected-category-id="selectedCategoryId" @update:selected-category-id="selectedCategoryId = $event" @changed="emit('changed')" />
    <form class="admin-topology-form admin-topology-form--channel" @submit.prevent="submitChannel">
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
    <AdminChannelRename :categories="props.categories" :revision="props.revision" @changed="emit('changed')" />
    <AdminChannelMove :categories="props.categories" :revision="props.revision" @changed="emit('changed')" />
    <AdminChannelOrder :categories="props.categories" :revision="props.revision" @changed="emit('changed')" />
    <AdminTextArchive :categories="props.categories" :revision="props.revision" @changed="emit('changed')" />
    <AdminVoiceClose :categories="props.categories" :revision="props.revision" @changed="emit('changed')" />
    <p v-if="status" class="admin-topology-status" aria-live="polite">{{ status }}</p>
    <p v-if="error" class="admin-topology-error" role="alert">{{ error }}</p>
  </section>
</template>
