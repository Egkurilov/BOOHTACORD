<script setup lang="ts">
import { computed } from 'vue'
import type { TopologyCategory } from './topology_client'

const props = defineProps<{ categories: TopologyCategory[]; selectedId: string }>()
const emit = defineEmits<{ select: [id: string] }>()
const ordered = computed(() => [...props.categories].sort((a, b) => a.position - b.position || a.id.localeCompare(b.id)))
function channels(category: TopologyCategory) {
  return [...category.channels].sort((a, b) => a.position - b.position || a.id.localeCompare(b.id))
}
</script>

<template>
  <nav class="admin-topology-tree" aria-label="Структура разделов и каналов">
    <p class="admin-topology-tree__caption">СТРУКТУРА КАНАЛОВ</p>
    <p v-if="!ordered.length" class="admin-topology-tree__empty">Разделов пока нет.</p>
    <section v-for="category in ordered" :key="category.id" class="admin-topology-tree__category">
      <button type="button" class="admin-topology-tree__category-button" :aria-current="selectedId === category.id ? 'true' : undefined"
        :aria-label="`Выбрать раздел ${category.name}`" @click="emit('select', category.id)">
        <span aria-hidden="true">⌄</span><span>{{ category.name }}</span><small>{{ category.channels.length }}</small>
      </button>
      <button v-for="channel in channels(category)" :key="channel.id" type="button" class="admin-topology-tree__channel"
        :aria-current="selectedId === channel.id ? 'true' : undefined"
        :aria-label="`Выбрать ${channel.kind === 'VOICE' ? 'голосовой' : 'текстовый'} канал ${channel.name}`"
        @click="emit('select', channel.id)">
        <span class="admin-topology-tree__icon" aria-hidden="true"><template v-if="channel.kind === 'TEXT'">#</template>
          <svg v-else viewBox="0 0 24 24"><path d="m11 5-6 4H2v6h3l6 4V5ZM15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14" /></svg>
        </span>
        <span class="admin-topology-tree__name">{{ channel.name }}</span>
        <small v-if="channel.admissionClosed">Вход закрыт</small>
      </button>
    </section>
  </nav>
</template>
