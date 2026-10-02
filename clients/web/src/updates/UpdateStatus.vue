<script setup lang="ts">
import { buildLabel } from './build_identity'
import { useUpdateStore } from './update_store'
const updates = useUpdateStore()
const labels: Record<string,string> = { up_to_date:'Установлена актуальная версия', update_available:'Доступно обновление', current_ahead:'Эта сборка новее опубликованной', no_published_target:'Канал обновлений пока не настроен', unsupported_environment:'Новая версия требует другую версию ОС', identity_conflict:'Не удалось подтвердить сборку приложения', identity_unknown:'Не удалось определить сборку приложения', check_unavailable:'Не удалось проверить обновления' }
</script>

<template>
  <section class="profile-logout" aria-labelledby="client-version-title">
    <h2 id="client-version-title">Версия приложения</h2>
    <p>{{ buildLabel }} · {{ updates.result ? labels[updates.result] : 'Ещё не проверено' }}<span v-if="updates.stale"> · данные устарели</span></p>
    <p v-if="updates.lastSuccessfulCheckAt">Последняя проверка: {{ updates.lastSuccessfulCheckAt.toLocaleString('ru-RU') }}</p>
    <button class="profile-secondary-button" type="button" :disabled="updates.checkStatus === 'checking'" @click="updates.manual">{{ updates.checkStatus === 'checking' ? 'Проверяем…' : 'Проверить обновления' }}</button>
    <p v-if="updates.error" class="profile-error" role="alert">{{ updates.error }}</p>
  </section>
</template>
