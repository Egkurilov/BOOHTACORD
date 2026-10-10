<script setup lang="ts">
import { nextTick, onBeforeUnmount, ref } from 'vue'
import { createVoiceTimeoutState } from './state'
import type { Reason } from './client'
const props = defineProps<{ accountId: string; login: string }>()
const state = createVoiceTimeoutState(props.accountId)
const { value, busy, error } = state
const open = ref(false), minutes = ref(15), reason = ref<Reason>('DISRUPTION')
const refresh = ref<HTMLButtonElement | null>(null)
const reasonNames: Record<Reason, string> = { DISRUPTION: 'Мешает разговору', HARASSMENT: 'Оскорбления', SPAM: 'Спам', OTHER: 'Другое' }
async function toggle(): Promise<void> { open.value = !open.value; if (open.value) await state.load() }
async function clear(event: MouseEvent): Promise<void> {
  const wasFocused = document.activeElement === event.currentTarget
  await state.clear(); await nextTick()
  if (wasFocused && document.activeElement === document.body) refresh.value?.focus()
}
onBeforeUnmount(state.dispose)
</script>
<template>
  <div class="voice-timeout-control">
    <button type="button" :aria-expanded="open" :aria-label="`Ограничение голоса: ${login}`" :disabled="busy" @click="toggle">Ограничение голоса</button>
    <section v-if="open" :aria-label="`Ограничение голоса для ${login}`">
      <p v-if="busy" role="status">Обновляем ограничение голоса…</p>
      <template v-if="value">
        <p role="status" v-if="value.active">Голос ограничен до <time :datetime="value.expires_at">{{ new Date(value.expires_at!).toLocaleString('ru-RU') }}</time>.</p>
        <p v-if="value.active">Причина: {{ reasonNames[value.reason_code!] }}</p>
        <p role="status" v-else>Активного ограничения голоса нет.</p>
        <p v-if="value.revocation_pending" role="status">Отключение поставлено в очередь. Физическое завершение ещё не подтверждено.</p>
        <form @submit.prevent="state.set(minutes, reason)">
          <label>Срок<select v-model.number="minutes" :disabled="busy" :aria-label="`Срок ограничения: ${login}`"><option :value="5">5 минут</option><option :value="15">15 минут</option><option :value="60">1 час</option><option :value="240">4 часа</option><option :value="1440">24 часа</option></select></label>
          <label>Причина<select v-model="reason" :disabled="busy" :aria-label="`Причина ограничения: ${login}`"><option v-for="(name, code) in reasonNames" :key="code" :value="code">{{ name }}</option></select></label>
          <p>Ограничение затрагивает только голос и не меняет доступ к чатам. После истечения срока потребуется явное подключение; микрофон сам не включится.</p>
          <button type="submit" :disabled="busy" :aria-label="`Подтвердить ограничение голоса: ${login}`">Подтвердить ограничение</button>
          <button v-if="value.active" type="button" :disabled="busy" :aria-label="`Снять ограничение голоса: ${login}`" @click="clear">Снять ограничение</button>
        </form>
      </template>
      <p v-if="error" role="alert">{{ error }}</p>
      <button ref="refresh" type="button" :disabled="busy" :aria-label="`Обновить ограничение голоса: ${login}`" @click="state.load">Обновить состояние</button>
    </section>
  </div>
</template>
<style scoped>
.voice-timeout-control section { max-width: 360px; display: grid; gap: 8px; }
form { display: grid; gap: 8px; } p { font-size: 0.8125rem; overflow-wrap: anywhere; }
</style>
