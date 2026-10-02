<script setup lang="ts">
withDefaults(defineProps<{ membersExpanded: boolean; navExpanded: boolean; showMembers?: boolean }>(), { showMembers: true })
const emit = defineEmits<{ toggleMembers: []; toggleNavigation: [] }>()
</script>

<template>
  <div class="header-actions workspace-header-actions">
    <slot />
    <button class="header-action workspace-header-toggle workspace-header-toggle--nav" type="button" aria-label="Открыть навигацию" aria-controls="nav-sidebar" :aria-expanded="navExpanded" @click="emit('toggleNavigation')">
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16" /></svg>
    </button>
    <button v-if="showMembers" class="header-action workspace-header-toggle workspace-header-toggle--members" type="button" :aria-label="membersExpanded ? 'Скрыть участников' : 'Открыть участников'" aria-controls="members-panel" :aria-expanded="membersExpanded" @click="emit('toggleMembers')">
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2M9.5 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM20 8v6m3-3h-6" /></svg>
    </button>
    <slot name="overflow" />
  </div>
</template>
