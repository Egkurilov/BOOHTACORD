<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import type { TopologyCategory } from '../../channel/topology_client'
import AdminTopologyControls from '../../channel/AdminTopologyControls.vue'
import AdminMembersSection from '../members/AdminMembersSection.vue'
import AdminAuditSection from '../audit/AdminAuditSection.vue'
import AdminMediaDiagnostics from '../media/AdminMediaDiagnostics.vue'
import AdminRolePermissions from '../role_permissions/AdminRolePermissions.vue'

defineProps<{ categories: TopologyCategory[]; revision: number }>()
const emit = defineEmits<{ topologyChanged: [] }>()
const section = ref<'members' | 'roles' | 'channels' | 'audit' | 'media'>('members')
const title = ref<HTMLElement | null>(null)
let focusFrame: number | null = null
onMounted(() => { focusFrame = window.requestAnimationFrame(() => title.value?.focus()) })
onBeforeUnmount(() => { if (focusFrame !== null) window.cancelAnimationFrame(focusFrame) })
</script>

<template>
  <section class="admin-panel" aria-labelledby="admin-panel-title" data-testid="admin-panel">
    <header class="admin-panel-heading"><div><p class="admin-eyebrow">УПРАВЛЕНИЕ ГИЛЬДИЕЙ</p><h1 id="admin-panel-title" ref="title" tabindex="-1">Администрирование</h1></div></header>
    <nav class="admin-section-tabs" aria-label="Разделы администрирования">
      <button type="button" :aria-current="section === 'members' ? 'page' : undefined" @click="section = 'members'">Участники</button>
      <button type="button" :aria-current="section === 'roles' ? 'page' : undefined" @click="section = 'roles'">Роли</button>
      <button type="button" :aria-current="section === 'channels' ? 'page' : undefined" @click="section = 'channels'">Каналы</button>
      <button type="button" :aria-current="section === 'audit' ? 'page' : undefined" @click="section = 'audit'">Аудит</button>
      <button type="button" :aria-current="section === 'media' ? 'page' : undefined" @click="section = 'media'">Медиа</button>
    </nav>
    <AdminMembersSection v-if="section === 'members'" />
    <AdminRolePermissions v-else-if="section === 'roles'" />
    <AdminTopologyControls v-else-if="section === 'channels'" :categories="categories" :revision="revision" @changed="emit('topologyChanged')" />
    <AdminAuditSection v-else-if="section === 'audit'" />
    <AdminMediaDiagnostics v-else />
  </section>
</template>
