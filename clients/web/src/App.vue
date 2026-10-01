<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue'

import AuthenticationLanding from './identity/AuthenticationLanding.vue'
import { clearAuthenticatedState } from './identity/clear_authenticated_state'
import { loadCurrentSession, type CurrentSession } from './identity/current_session'
import PasswordResetCompletion from './identity/PasswordResetCompletion.vue'
import { completePasswordReset, PasswordResetInvalidError } from './identity/password_reset_client'
import { consumePasswordResetFragment } from './identity/password_reset_fragment'
import MaintenanceBanner from './maintenance/MaintenanceBanner.vue'
import { loadMaintenanceStatus } from './maintenance/status_client'
import WorkspaceApp from './workspace/WorkspaceApp.vue'

type AppState = 'loading' | 'guest' | 'authenticated' | 'error'

const state = ref<AppState>('loading')
const error = ref<string | null>(null)
const session = ref<CurrentSession | null>(null)
const maintenanceActive = ref(false)
const resetRoute = ref(false)
const focusLoginOnReturn = ref(false)
let resetToken: string | null = null
if (typeof window !== 'undefined') {
  const reset = consumePasswordResetFragment(window.location, window.history)
  resetRoute.value = reset.resetRoute
  resetToken = reset.token
}
let maintenanceTimer: number | null = null
let sessionRevision = 0

async function refreshSession(): Promise<void> {
  const revision = ++sessionRevision
  if (session.value) { clearAuthenticatedState(); session.value = null }
  state.value = 'loading'
  error.value = null
  try {
    const current = await loadCurrentSession()
    if (revision !== sessionRevision) return
    session.value = current
    state.value = session.value ? 'authenticated' : 'guest'
  } catch (cause) {
    if (revision !== sessionRevision) return
    session.value = null
    error.value = cause instanceof Error ? cause.message : 'Не удалось проверить сессию.'
    state.value = 'error'
  }
}

function finishLogout(): void {
  sessionRevision++
  session.value = null
  error.value = null
  state.value = 'guest'
}

async function finishPasswordReset(password: string): Promise<void> {
  const token = resetToken
  if (!token) throw new PasswordResetInvalidError()
  await completePasswordReset(token, password)
  resetToken = null
}

function returnToLogin(): void {
  resetToken = null
  resetRoute.value = false
  focusLoginOnReturn.value = true
  sessionRevision++
  session.value = null
  clearAuthenticatedState()
  error.value = null
  state.value = 'guest'
  window.history.replaceState(window.history.state, '', '/')
}

async function refreshMaintenance(): Promise<void> {
  try {
    maintenanceActive.value = (await loadMaintenanceStatus()).active
  } catch {
    maintenanceActive.value = false
  }
}

onMounted(() => {
  if (!resetRoute.value) void refreshSession()
  void refreshMaintenance()
  maintenanceTimer = window.setInterval(() => { void refreshMaintenance() }, 5_000)
})

onUnmounted(() => {
  if (maintenanceTimer !== null) window.clearInterval(maintenanceTimer)
})
</script>

<template>
  <MaintenanceBanner v-if="maintenanceActive" />
  <PasswordResetCompletion v-if="resetRoute" :valid-link="Boolean(resetToken)" :complete="finishPasswordReset" @invalid-link="resetToken = null" @return-to-login="returnToLogin" />
  <main v-else-if="state === 'loading'" class="session-state" aria-live="polite">Проверяем безопасную сессию…</main>
  <main v-else-if="state === 'error'" class="session-state" role="alert">
    <p>{{ error }}</p>
    <button type="button" @click="refreshSession">Повторить</button>
  </main>
  <AuthenticationLanding v-else-if="state === 'guest'" :focus-login-on-mount="focusLoginOnReturn" @authenticated="refreshSession" />
  <WorkspaceApp v-else-if="session" :key="session.accountId" :role="session.role" :account-id="session.accountId" @session-expired="refreshSession" @logged-out="finishLogout" />
</template>
