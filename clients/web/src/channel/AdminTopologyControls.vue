<script setup lang="ts">
import { computed, nextTick, ref, watch } from 'vue'
import AdminTopologyTree from './AdminTopologyTree.vue'
import AdminCategoryControls from './AdminCategoryControls.vue'
import AdminChannelCreate from './AdminChannelCreate.vue'
import AdminChannelRename from './AdminChannelRename.vue'
import AdminChannelDescription from './AdminChannelDescription.vue'
import AdminChannelMove from './AdminChannelMove.vue'
import AdminChannelOrder from './AdminChannelOrder.vue'
import AdminTextArchive from './AdminTextArchive.vue'
import AdminVoiceClose from './AdminVoiceClose.vue'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; revision: number }>()
const emit = defineEmits<{ changed: [] }>()
const selectedId = ref('')
const inspector = ref<HTMLElement | null>(null)
const selectedCategory = computed(() => props.categories.find(({ id }) => id === selectedId.value))
const selectedChannel = computed(() => props.categories.flatMap(({ channels }) => channels).find(({ id }) => id === selectedId.value))
const parentCategory = computed(() => selectedCategory.value ?? props.categories.find(({ channels }) => channels.some(({ id }) => id === selectedId.value)))
const channelPosition = computed(() => [...(parentCategory.value?.channels ?? [])]
  .sort((a, b) => a.position - b.position || a.id.localeCompare(b.id)).findIndex(({ id }) => id === selectedId.value) + 1)

watch(() => props.categories, (categories) => {
  if (!categories.some(({ id, channels }) => id === selectedId.value || channels.some(({ id: channelId }) => channelId === selectedId.value))) {
    selectedId.value = [...categories].sort((a, b) => a.position - b.position)[0]?.id ?? ''
  }
}, { immediate: true })

async function select(id: string): Promise<void> {
  selectedId.value = id
  await nextTick()
  if (window.matchMedia('(max-width: 900px)').matches) inspector.value?.scrollIntoView({ block: 'start' })
}
</script>

<template>
  <section class="admin-topology-controls" aria-labelledby="admin-topology-title">
    <h2 id="admin-topology-title">Управление каналами</h2>
    <div class="admin-topology-workspace">
      <AdminTopologyTree :categories="categories" :selected-id="selectedId" @select="select" />
      <div ref="inspector" class="admin-topology-inspector">
        <template v-if="selectedCategory || !categories.length">
          <header><span class="admin-topology-inspector__eyebrow">РАЗДЕЛ</span><h3>{{ selectedCategory?.name ?? 'Новый раздел' }}</h3>
            <p>Каналов: {{ selectedCategory?.channels.length ?? 0 }} · Порядок: {{ (selectedCategory?.position ?? 0) + 1 }}</p></header>
          <AdminCategoryControls embedded :categories="categories" :revision="revision" :selected-category-id="selectedId"
            @update:selected-category-id="selectedId = $event" @changed="emit('changed')" />
          <AdminChannelCreate v-if="selectedCategory" :categories="categories" :category-id="selectedId" @changed="emit('changed')" />
        </template>
        <template v-else-if="selectedChannel">
          <header><span class="admin-topology-inspector__eyebrow">{{ selectedChannel.kind === 'VOICE' ? 'ГОЛОСОВОЙ КАНАЛ' : 'ТЕКСТОВЫЙ КАНАЛ' }}</span>
            <h3>{{ selectedChannel.name }}</h3><p>Раздел: {{ parentCategory?.name }} · Порядок: {{ channelPosition }}</p></header>
          <AdminChannelRename :categories="categories" :revision="revision" :channel-id="selectedId" @changed="emit('changed')" />
          <AdminChannelDescription :channel-id="selectedId" :description="selectedChannel.description" :revision="revision" @changed="emit('changed')" />
          <AdminChannelMove :categories="categories" :revision="revision" :channel-id="selectedId" @changed="emit('changed')" />
          <AdminChannelOrder :categories="categories" :revision="revision" :channel-id="selectedId" @changed="emit('changed')" />
          <section class="admin-topology-danger" aria-label="Опасные действия">
            <h4>Опасные действия</h4>
            <AdminTextArchive v-if="selectedChannel.kind === 'TEXT'" :categories="categories" :revision="revision" :channel-id="selectedId" @changed="emit('changed')" />
            <AdminVoiceClose v-else :categories="categories" :revision="revision" :channel-id="selectedId" @changed="emit('changed')" />
          </section>
        </template>
      </div>
    </div>
  </section>
</template>
