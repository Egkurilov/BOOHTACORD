import { defineStore } from 'pinia'
import { ref } from 'vue'

import { PushToTalk, type EventSource } from './push_to_talk'
import { useVoiceConnectionStore } from './connection_store'

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
    pttKey.value = key
    error.value = null
    if (mode.value === 'PTT') await startPtt()
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

  return { error, mode, pttKey, setMode, setPttKey, stop }
})
