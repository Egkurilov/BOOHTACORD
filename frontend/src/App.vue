<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'

import AuthenticationLanding from './identity/AuthenticationLanding.vue'
import { loadCurrentSession, type CurrentSession } from './identity/current_session'
import MaintenanceBanner from './maintenance/MaintenanceBanner.vue'
import { loadMaintenanceStatus } from './maintenance/status_client'
import WorkspaceApp from './workspace/WorkspaceApp.vue'

type AppState = 'loading' | 'guest' | 'authenticated' | 'error'

const state = ref<AppState>('loading')
const error = ref<string | null>(null)
const session = ref<CurrentSession | null>(null)
const maintenanceActive = ref(false)
let maintenanceTimer: ReturnType<typeof setInterval> | null = null

async function refreshSession(): Promise<void> {
  state.value = 'loading'
  error.value = null
  try {
    session.value = await loadCurrentSession()
    state.value = session.value ? 'authenticated' : 'guest'
  } catch (cause) {
    session.value = null
    error.value = cause instanceof Error ? cause.message : 'Не удалось проверить сессию.'
    state.value = 'error'
  }
}

async function refreshMaintenance(): Promise<void> {
  try {
    maintenanceActive.value = (await loadMaintenanceStatus()).active
  } catch {
    maintenanceActive.value = false
  }
}

onMounted(() => {
  void refreshSession()
  void refreshMaintenance()
  maintenanceTimer = window.setInterval(() => { void refreshMaintenance() }, 5_000)
})

onUnmounted(() => {
  if (maintenanceTimer !== null) window.clearInterval(maintenanceTimer)
})
</script>

<template>
  <MaintenanceBanner v-if="maintenanceActive" />
  <main v-if="state === 'loading'" class="session-state" aria-live="polite">Проверяем безопасную сессию…</main>
  <main v-else-if="state === 'error'" class="session-state" role="alert">
    <p>{{ error }}</p>
    <button type="button" @click="refreshSession">Повторить</button>
  </main>
  <AuthenticationLanding v-else-if="state === 'guest'" @authenticated="refreshSession" />
  <WorkspaceApp v-else-if="session" :role="session.role" />
</template>
