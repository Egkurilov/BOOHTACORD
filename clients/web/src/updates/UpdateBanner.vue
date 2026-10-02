<script setup lang="ts">
import { ref } from 'vue'
import { useUpdateStore } from './update_store'

const updates = useUpdateStore(); const details = ref(false)
</script>

<template>
  <section v-if="updates.visible" class="update-banner" aria-live="polite" aria-label="Доступно обновление клиента">
    <div><strong>Доступно обновление BOOHTACORD</strong><span>{{ updates.policy?.target?.summary || 'Загрузилась новая версия приложения.' }}</span></div>
    <nav aria-label="Действия с обновлением">
      <button type="button" @click="updates.apply">Обновить</button>
      <button type="button" @click="details = !details">Что нового</button>
      <button type="button" @click="updates.later">Позже</button>
    </nav>
    <div v-if="details" class="update-details">
      <p>{{ updates.policy?.target?.version ? `Версия ${updates.policy.target.version}` : 'Новая web-сборка' }}</p>
      <a v-if="updates.policy?.target?.release_notes_url" :href="updates.policy.target.release_notes_url" target="_blank" rel="noopener noreferrer">Описание выпуска</a>
    </div>
  </section>
</template>

<style scoped>
.update-banner{display:flex;align-items:center;gap:16px;flex-wrap:wrap;padding:10px 18px;background:#173b63;color:#f7fbff;border-bottom:1px solid #4d8bc5;position:relative;z-index:20}.update-banner div:first-child{display:grid;gap:2px;flex:1}.update-banner span,.update-details{font-size:13px;color:#d7e9fa}.update-banner nav{display:flex;gap:8px}.update-banner button{border:1px solid #7fb3e0;border-radius:6px;background:#245789;color:white;padding:7px 11px;cursor:pointer}.update-details{flex-basis:100%;display:flex;gap:14px}.update-details p{margin:0}.update-details a{color:#fff}
</style>
