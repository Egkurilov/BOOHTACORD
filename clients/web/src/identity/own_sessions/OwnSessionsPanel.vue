<script setup lang="ts">
import { onBeforeUnmount, onServerPrefetch, watch } from 'vue'
import { createOwnSessionsState } from './state'
const props = defineProps<{ accountId: string }>()
const emit = defineEmits<{ sessionExpired: [] }>()
const state = createOwnSessionsState()
const { items, error, busy, nextCursor, expired } = state
watch(() => props.accountId, account => { state.setAccount(account); void state.refresh() }, { immediate: true })
watch(expired, value => { if (value) emit('sessionExpired') })
onServerPrefetch(async () => { while (busy.value) await new Promise(resolve => setTimeout(resolve, 0)); state.stopListening() })
onBeforeUnmount(state.close)
function timestamp(value: string): string { return new Date(value).toLocaleString('ru-RU', { dateStyle: 'short', timeStyle: 'short' }) }
</script>
<template>
  <section class="own-sessions" aria-labelledby="own-sessions-title" :aria-busy="busy">
    <h2 id="own-sessions-title">Активные сеансы</h2>
    <p>Завершённый сеанс потеряет доступ к сообщениям и голосу.</p>
    <p v-if="error" role="alert">{{ error }}</p>
    <p v-if="busy" role="status">Обновляем сеансы…</p>
    <ul>
      <li v-for="session in items" :key="session.id">
        <div><strong>{{ session.label }}</strong><span v-if="session.current"> · Этот сеанс</span>
          <p>Вход: {{ timestamp(session.createdAt) }}<br>Активность: {{ timestamp(session.lastActiveAt) }}</p></div>
        <button class="profile-secondary-button" data-testid="session-revoke" type="button" :disabled="busy || session.current" :aria-label="session.current ? 'Текущий сеанс сохраняется' : `Завершить сеанс от ${timestamp(session.createdAt)}`" @click="state.revoke(session.id)">Завершить</button>
      </li>
    </ul>
    <div class="own-sessions-actions">
      <button class="profile-secondary-button" type="button" :disabled="busy" @click="state.refresh">Обновить</button>
      <button v-if="nextCursor" class="profile-secondary-button" type="button" :disabled="busy" @click="state.more">Показать ещё</button>
      <button class="profile-secondary-button" data-testid="sessions-revoke-others" type="button" :disabled="busy || !items.some(row => !row.current)" @click="state.revokeOthers">Завершить все остальные</button>
    </div>
    <small>Текущий сеанс останется активным.</small>
  </section>
</template>
<style scoped>
.own-sessions { border-top: 1px solid var(--gc-border-subtle); margin-top: 24px; padding-top: 24px; }
.own-sessions ul { list-style: none; padding: 0; }
.own-sessions li { display: flex; gap: 16px; justify-content: space-between; align-items: center; padding: 12px 0; }
.own-sessions li div { min-width: 0; overflow-wrap: anywhere; }
.own-sessions li p, .own-sessions small { color: var(--gc-text-muted); }
.own-sessions-actions { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 12px; }
</style>
