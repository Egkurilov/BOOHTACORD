<script setup lang="ts">
import { computed, onMounted, onBeforeUnmount } from 'vue'
import type { TopologyCategory } from '../../channel/topology_client'
import { createGuildSettingsState } from './state'
const props = defineProps<{ categories: TopologyCategory[] }>()
const state = createGuildSettingsState()
const { name, welcome, revision, busy, error, saved } = state
const channels = computed(() => props.categories.flatMap(category => category.channels).filter(channel => channel.kind === 'TEXT' && !channel.admissionClosed))
onMounted(() => { void state.load() }); onBeforeUnmount(state.dispose)
</script>
<template>
  <form class="guild-settings" aria-label="Настройки гильдии" @submit.prevent="state.save(channels.map(channel => channel.id))">
    <h2>Гильдия</h2>
    <p>Название отображается участникам и на экране входа.</p>
    <label for="guild-name">Название гильдии</label><input id="guild-name" v-model="name" :disabled="busy || !revision" autocomplete="off" aria-describedby="guild-name-help">
    <small id="guild-name-help">От 1 до 80 символов, без переводов строк.</small>
    <label for="guild-welcome">Приветствия новых участников</label>
    <select id="guild-welcome" v-model="welcome" :disabled="busy || !revision">
      <option :value="null">Не отправлять</option>
      <option v-if="welcome && !channels.some(channel => channel.id === welcome)" :value="welcome" disabled>Выбранный канал недоступен</option>
      <option v-for="channel in channels" :key="channel.id" :value="channel.id"># {{ channel.name }}</option>
    </select>
    <small v-if="!channels.length">Нет доступных текстовых каналов. Приветствия можно оставить выключенными.</small>
    <p v-if="error" role="alert">{{ error }}</p><p v-if="saved" role="status">Настройки сохранены.</p>
    <button type="submit" :disabled="busy || !revision">{{ busy ? 'Сохраняем…' : 'Сохранить' }}</button>
    <button v-if="!revision && !busy" type="button" @click="state.load">Загрузить настройки</button>
  </form>
</template>
<style scoped>
.guild-settings { display: grid; gap: 12px; max-width: 580px; padding: 24px; }
input, select { min-width: 0; width: 100%; padding: 10px; color: var(--gc-text-primary); background: var(--gc-surface); border: 1px solid var(--gc-border-control); border-radius: 8px; }
button { justify-self: start; padding: 10px 16px; }
</style>
