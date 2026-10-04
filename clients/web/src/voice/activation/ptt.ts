import type { Ref } from 'vue'
import { PushToTalk, type EventSource } from '../push_to_talk'
import { useVoiceConnectionStore } from '../connection_store'
let pushToTalk: PushToTalk | null = null
let mutedBeforePtt: boolean | null = null
let queuedChange = Promise.resolve()

function browserEvents(): EventSource {
  return {
    addEventListener: (type, listener) => (type === 'visibilitychange' ? document : window).addEventListener(type, listener as unknown as EventListener),
    removeEventListener: (type, listener) => (type === 'visibilitychange' ? document : window).removeEventListener(type, listener as unknown as EventListener),
  }
}

export function createPttActivation(pttKey: Ref<string | null>, error: Ref<string | null>) {
  async function start(): Promise<void> {
    const voice = useVoiceConnectionStore()
    if (!voice.active) {
      error.value = 'Сначала подключитесь к голосовому каналу.'
      return
    }

    await stop(false)
    mutedBeforePtt = voice.microphoneMuted
    await voice.setMicrophoneMuted(true)
    if (!pttKey.value) {
      error.value = 'Для push-to-talk назначьте клавишу.'
      return
    }
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

  return { start, stop }
}
