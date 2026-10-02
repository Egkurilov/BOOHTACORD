<script setup lang="ts">
import { ref } from 'vue'

import { useDirectMessageCandidateStore } from './direct_message_candidate_store'

const emit = defineEmits<{ open: [directMessageId: string] }>()
const store = useDirectMessageCandidateStore()
const visible = ref(false)

function show(): void { visible.value = true; void store.refresh() }
function hide(): void { visible.value = false }
function refresh(): void { void store.refresh() }
async function choose(participantId: string): Promise<void> {
  const directMessageId = await store.open(participantId)
  if (!directMessageId) return
  hide()
  emit('open', directMessageId)
}
</script>

<template>
  <button class="channel-button" type="button" @click="show">Начать диалог</button>
  <section v-if="visible" class="starter" role="dialog" aria-modal="true" aria-labelledby="direct-message-starter-title">
    <header class="starter-header">
      <h3 id="direct-message-starter-title">Новый личный диалог</h3>
      <button type="button" aria-label="Закрыть выбор участника" @click="hide">×</button>
    </header>
    <p v-if="store.loading" class="empty-category" aria-live="polite">Загружаем участников…</p>
    <p v-if="store.error" class="empty-category state-error" role="alert">{{ store.error }}</p>
    <p v-else-if="!store.loading && !store.candidates.length" class="empty-category">Нет доступных участников.</p>
    <div v-if="store.candidates.length" class="candidate-list">
      <button v-for="candidate in store.candidates" :key="candidate.id" class="channel-button" type="button" :disabled="store.opening" @click="choose(candidate.id)">
        {{ candidate.displayName }}
      </button>
    </div>
    <button v-if="store.error" class="channel-button" type="button" :disabled="store.loading" @click="refresh">Обновить список</button>
    <button v-if="store.nextAfter" class="channel-button" type="button" :disabled="store.loading || store.opening" @click="store.loadNext()">Загрузить ещё</button>
  </section>
</template>
