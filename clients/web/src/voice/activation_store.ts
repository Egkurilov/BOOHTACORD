import { defineStore } from 'pinia'
import { ref } from 'vue'

import { PushToTalk, type EventSource } from './push_to_talk'
import { useVoiceConnectionStore } from './connection_store'
import { loadVoiceShortcutPreferences, saveVoiceShortcutPreferences } from './voice_shortcut_preferences'
import { isVoiceShortcutValid, shortcutConflict, type VoiceShortcutAction, type VoiceShortcutBinding } from './voice_shortcut'

export type VoiceActivationMode = 'VAD' | 'PTT'

let pushToTalk: PushToTalk | null = null
let mutedBeforePtt: boolean | null = null
let queuedChange = Promise.resolve()

function browserEvents(): EventSource {
  return {
    addEventListener: (type, listener) => (type === 'visibilitychange' ? document : window).addEventListener(type, listener as unknown as EventListener),
    removeEventListener: (type, listener) => (type === 'visibilitychange' ? document : window).removeEventListener(type, listener as unknown as EventListener),
  }
}

export const useVoiceActivationStore = defineStore('voice-activation', () => {
  const error = ref<string | null>(null)
  const mode = ref<VoiceActivationMode>('VAD')
  const pttKey = ref<string | null>(null)
  const microphoneShortcut = ref<VoiceShortcutBinding | null>(null)
  const deafenShortcut = ref<VoiceShortcutBinding | null>(null)
  const shortcutStatus = ref('')
  let accountId: string | null = null

  function bindAccount(nextAccountId: string): void {
    if (accountId === nextAccountId) return
    accountId = nextAccountId
    const preferences = loadVoiceShortcutPreferences(nextAccountId)
    microphoneShortcut.value = preferences.microphone
    deafenShortcut.value = preferences.deafen
  }

  async function setMode(nextMode: VoiceActivationMode): Promise<void> {
    mode.value = nextMode
    error.value = null
    if (nextMode === 'VAD') {
      await stop()
      return
    }
    await startPtt()
  }

  async function setPttKey(key: string): Promise<void> {
    if (microphoneShortcut.value?.code === key || deafenShortcut.value?.code === key) {
      error.value = 'Эта клавиша уже назначена для другого действия.'
      return
    }
    pttKey.value = key
    error.value = null
    if (mode.value === 'PTT') await startPtt()
  }

  function setShortcut(action: VoiceShortcutAction, binding: VoiceShortcutBinding | null): boolean {
    if (binding && !isVoiceShortcutValid(binding)) {
      error.value = 'Назначьте сочетание с Ctrl, Alt, Shift или Meta и основной клавишей.'
      return false
    }
    if (binding) {
      const other = action === 'microphone' ? deafenShortcut.value : microphoneShortcut.value
      const conflict = shortcutConflict(binding, other, pttKey.value)
      if (conflict) {
        error.value = conflict === 'duplicate' ? 'Это сочетание уже назначено.' : conflict === 'ptt' ? 'Сочетание конфликтует с push-to-talk.' : 'Ctrl/Meta+K зарезервировано для поиска.'
        return false
      }
    }
    if (action === 'microphone') microphoneShortcut.value = binding
    else deafenShortcut.value = binding
    if (accountId) saveVoiceShortcutPreferences(accountId, { microphone: microphoneShortcut.value, deafen: deafenShortcut.value })
    error.value = null
    return true
  }

  function announceShortcut(action: VoiceShortcutAction): void {
    const voice = useVoiceConnectionStore()
    if (!voice.active) {
      shortcutStatus.value = action === 'microphone' ? 'Микрофон недоступен: подключитесь к голосовому каналу.' : 'Звук недоступен: подключитесь к голосовому каналу.'
      return
    }
    shortcutStatus.value = action === 'microphone'
      ? voice.deafened || voice.microphonePermissionDenied
        ? 'Микрофон остаётся выключенным.'
        : voice.microphoneMuted ? 'Микрофон выключен.' : 'Микрофон включён.'
      : voice.deafened ? 'Звук выключен.' : 'Звук включён.'
  }

  async function startPtt(): Promise<void> {
    const voice = useVoiceConnectionStore()
    if (!pttKey.value) {
      error.value = 'Для push-to-talk назначьте клавишу.'
      return
    }
    if (!voice.active) {
      error.value = 'Сначала подключитесь к голосовому каналу.'
      return
    }

    await stop(false)
    mutedBeforePtt = voice.microphoneMuted
    await voice.setMicrophoneMuted(true)
    pushToTalk = new PushToTalk(browserEvents(), pttKey.value, (pressed) => {
      queuedChange = queuedChange.then(() => voice.setMicrophoneMuted(!pressed))
    })
    pushToTalk.start()
  }

  async function stop(restoreMute = true): Promise<void> {
    pushToTalk?.stop()
    pushToTalk = null
    await queuedChange
    if (restoreMute && mutedBeforePtt !== null) {
      await useVoiceConnectionStore().setMicrophoneMuted(mutedBeforePtt)
    }
    mutedBeforePtt = null
  }

  return { error, mode, pttKey, microphoneShortcut, deafenShortcut, shortcutStatus, bindAccount, setMode, setPttKey, setShortcut, announceShortcut, stop }
})
