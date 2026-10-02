<script setup lang="ts">
import { buildLabel } from './build_identity'
import { useUpdateStore } from './update_store'
const updates = useUpdateStore()
</script>

<template>
  <section class="profile-logout" aria-labelledby="client-version-title">
    <h2 id="client-version-title">Версия приложения</h2>
    <p>{{ buildLabel }} · {{ updates.result || 'ещё не проверено' }}<span v-if="updates.stale"> · данные устарели</span></p>
    <button class="profile-secondary-button" type="button" :disabled="updates.checkStatus === 'checking'" @click="updates.manual">{{ updates.checkStatus === 'checking' ? 'Проверяем…' : 'Проверить обновления' }}</button>
    <p v-if="updates.error" class="profile-error" role="alert">{{ updates.error }}</p>
  </section>
</template>
