<script setup lang="ts">
import { ref } from 'vue'
import type { TopologyCategory } from '../channel/topology_client'
import AdminTopologyControls from '../channel/AdminTopologyControls.vue'
import AdminMembersSection from './AdminMembersSection.vue'
import AdminAuditSection from './AdminAuditSection.vue'

defineProps<{ categories: TopologyCategory[]; revision: number }>()
const emit = defineEmits<{ topologyChanged: [] }>()
const section = ref<'members' | 'channels' | 'audit'>('members')
</script>

<template>
  <section class="admin-panel" aria-labelledby="admin-panel-title" data-testid="admin-panel">
    <header class="admin-panel-heading"><div><p class="admin-eyebrow">УПРАВЛЕНИЕ ГИЛЬДИЕЙ</p><h1 id="admin-panel-title">Администрирование</h1></div></header>
    <nav class="admin-section-tabs" aria-label="Разделы администрирования">
      <button type="button" :aria-current="section === 'members' ? 'page' : undefined" @click="section = 'members'">Участники</button>
      <button type="button" :aria-current="section === 'channels' ? 'page' : undefined" @click="section = 'channels'">Каналы</button>
      <button type="button" :aria-current="section === 'audit' ? 'page' : undefined" @click="section = 'audit'">Аудит</button>
    </nav>
    <AdminMembersSection v-if="section === 'members'" />
    <AdminTopologyControls v-else-if="section === 'channels'" :categories="categories" :revision="revision" @changed="emit('topologyChanged')" />
    <AdminAuditSection v-else />
  </section>
</template>
