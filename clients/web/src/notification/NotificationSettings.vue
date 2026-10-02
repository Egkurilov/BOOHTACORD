<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted } from 'vue'
import { useNotificationStore } from './notification_store'

const notifications = useNotificationStore()
onMounted(() => { notifications.refreshStatus(); window.addEventListener('focus', notifications.refreshStatus) })
onBeforeUnmount(() => window.removeEventListener('focus', notifications.refreshStatus))
const status = computed(() => {
  if (!notifications.available) return 'Системные уведомления недоступны в этом браузере.'
  if (notifications.permission === 'denied') return 'Браузер запретил уведомления. Разрешите их в настройках сайта.'
  return notifications.enabled ? 'Уведомления включены.' : 'Уведомления выключены.'
})
</script>

<template>
  <section class="profile-logout" aria-labelledby="profile-notifications-title">
    <h2 id="profile-notifications-title">Уведомления</h2>
    <p>Уведомления появляются при скрытой вкладке, пока браузер открыт. Текст личных сообщений в них не показывается.</p>
    <p aria-live="polite">{{ status }}</p>
    <button v-if="notifications.enabled" class="profile-secondary-button" type="button" @click="notifications.disable()">Отключить уведомления</button>
    <button v-else class="profile-secondary-button" type="button" :disabled="!notifications.available || notifications.permission === 'denied'" @click="notifications.enable()">Включить уведомления</button>
    <p v-if="notifications.error" class="profile-error" role="alert">{{ notifications.error }}</p>
  </section>
</template>
