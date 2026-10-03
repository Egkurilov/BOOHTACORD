<script setup lang="ts">
import { ref } from 'vue'
import { useUpdateStore } from './update_store'

const updates = useUpdateStore(); const details = ref(false)
</script>

<template>
  <section v-if="updates.visible" class="update-banner" aria-live="polite" aria-label="Доступно обновление клиента">
    <button class="update-summary" type="button" :aria-expanded="details" @click="details = !details"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 7v5h-5M4 17v-5h5M5 7a8 8 0 0 1 13-2l2 2M4 17l2 2a8 8 0 0 0 13-2" /></svg>Доступна новая версия BOOHTACORD</button>
    <nav aria-label="Действия с обновлением">
      <button type="button" class="update-primary" @click="updates.apply">Обновить страницу</button>
      <button type="button" @click="updates.later">Позже</button>
      <button type="button" class="update-dismiss" aria-label="Закрыть уведомление об обновлении" @click="updates.later"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="m6 6 12 12M18 6 6 18" /></svg></button>
    </nav>
    <div v-if="details" class="update-details">
      <p>{{ updates.policy?.target?.version ? `Версия ${updates.policy.target.version}` : 'Новая web-сборка' }}</p>
      <p>{{ updates.policy?.target?.summary || 'Загрузилась новая версия приложения.' }}</p>
      <a v-if="updates.policy?.target?.release_notes_url" :href="updates.policy.target.release_notes_url" target="_blank" rel="noopener noreferrer">Описание выпуска</a>
    </div>
  </section>
</template>
