<script setup lang="ts">
defineProps<{ active: 'channels' | 'messages' }>()

const emit = defineEmits<{
  select: [section: 'channels' | 'messages']
}>()
</script>

<template>
  <nav class="workspace-sidebar-tabs" aria-label="Разделы гильдии">
    <button class="gc-button gc-button--ghost" :class="{ 'is-selected': active === 'channels' }" :aria-pressed="active === 'channels'" type="button" @click="emit('select', 'channels')">Каналы</button>
    <button class="gc-button gc-button--ghost" :class="{ 'is-selected': active === 'messages' }" :aria-pressed="active === 'messages'" type="button" @click="emit('select', 'messages')">Личные</button>
  </nav>
</template>
