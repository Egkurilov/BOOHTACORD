<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue'
import { loadTopology, type TopologyChannel } from '../topology_client'
import { changeArchive } from './client'
const props = defineProps<{ revision: number; selectedArchive: string }>()
const emit = defineEmits<{ changed: [] }>()
const channels = ref<TopologyChannel[]>([]), selected = ref(''), confirmed = ref(false), busy = ref(false), error = ref('')
let disposed = false
onMounted(async () => { try { const topology = await loadTopology(); if (!disposed) channels.value = topology.categories.flatMap(category => category.channels).filter(channel => channel.kind === 'TEXT') } catch { if (!disposed) error.value = 'Не удалось загрузить активные каналы.' } })
onBeforeUnmount(() => { disposed = true })
async function change(archive: boolean): Promise<void> {
  if (busy.value || archive && (!selected.value || !confirmed.value)) return
  busy.value = true; error.value = ''
  try { await changeArchive(archive ? selected.value : props.selectedArchive, props.revision, archive); if (!disposed) emit('changed') }
  catch (reason) { if (!disposed) error.value = reason instanceof Error ? reason.message : 'Ошибка изменения архива.' }
  finally { if (!disposed) busy.value = false }
}
</script>
<template>
  <fieldset :disabled="busy"><legend>Управление архивом</legend><label>Активный TEXT-канал <select v-model="selected" aria-label="Активный TEXT-канал"><option value="">Выберите канал</option><option v-for="channel in channels" :key="channel.id" :value="channel.id">{{ channel.name }}</option></select></label><label><input v-model="confirmed" type="checkbox">Подтверждаю перевод в архив: история сохранится, отправка будет отключена.</label><button type="button" :disabled="!selected || !confirmed" @click="change(true)">Архивировать</button><button v-if="selectedArchive" type="button" @click="change(false)">Восстановить выбранный канал</button><p v-if="error" role="alert">{{ error }}</p></fieldset>
</template>
<style scoped>fieldset { display: grid; gap: 12px; border-color: var(--gc-border); } label { display: block; } select { max-width: 100%; }</style>
